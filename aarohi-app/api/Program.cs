using Aarohi;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.Data.SqlClient;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;

static bool IsPortTaken(int port)
{
    try
    {
        using var listener = new TcpListener(IPAddress.Loopback, port);
        listener.Start();
        return false;
    }
    catch (SocketException)
    {
        return true;
    }
}

static string ResolveApiUrl(string? configuredUrl)
{
    var preferredUrl = configuredUrl ?? Environment.GetEnvironmentVariable("AAROHI_BASE_URL") ?? "http://127.0.0.1:5088";
    if (!Uri.TryCreate(preferredUrl, UriKind.Absolute, out var uri) || uri.Port == 0)
    {
        return preferredUrl;
    }

    var startPort = uri.Port;
    var candidatePort = startPort;
    while (IsPortTaken(candidatePort))
    {
        candidatePort++;
        if (candidatePort > ushort.MaxValue)
        {
            throw new InvalidOperationException($"No free port was found starting from {startPort}.");
        }
    }

    if (candidatePort != startPort)
    {
        var next = new UriBuilder(uri) { Port = candidatePort };
        Console.WriteLine($"Port {startPort} is already in use; using {next.Uri} instead.");
        return next.Uri.ToString();
    }

    return preferredUrl;
}

var builder = WebApplication.CreateBuilder(args);
var configuredUrl = Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? Environment.GetEnvironmentVariable("AAROHI_BASE_URL") ?? "http://127.0.0.1:5088";
builder.WebHost.UseUrls(ResolveApiUrl(configuredUrl));
builder.Services.AddHttpClient("aarohi-price-fetcher");
builder.Services.AddSingleton<Db>(); builder.Services.AddSingleton<TokenService>();
var tokenService = new TokenService(builder.Configuration, builder.Environment); builder.Services.AddSingleton(tokenService);
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o => { o.MapInboundClaims = false; o.TokenValidationParameters = new() { ValidateIssuer = true, ValidIssuer = "aarohi-api", ValidateAudience = true, ValidAudience = "aarohi-web", ValidateLifetime = true, ValidateIssuerSigningKey = true, IssuerSigningKey = tokenService.Key, ValidAlgorithms = [SecurityAlgorithms.RsaSha256], ClockSkew = TimeSpan.FromSeconds(30) }; o.Events = new() { OnTokenValidated = async context => { var db = context.HttpContext.RequestServices.GetRequiredService<Db>(); var user = context.Principal!; await using var c = await db.Open(Db.Household(user)); var count = await Db.Scalar(c, "SELECT COUNT(*) FROM auth.Session s JOIN auth.UserAccount u ON u.Id=s.UserId JOIN family.Membership m ON m.UserId=u.Id JOIN auth.Role r ON r.Id=m.RoleId JOIN family.Household h ON h.Id=m.HouseholdId WHERE s.Id=@s AND u.Id=@u AND m.HouseholdId=@h AND u.Status='Active' AND m.Status='Active' AND r.IsActive=1 AND h.Status='Active' AND s.RevokedAt IS NULL AND s.ExpiresAt>SYSUTCDATETIME()", new() { ["s"] = long.Parse(user.FindFirstValue("sid")!), ["u"] = Db.User(user), ["h"] = Db.Household(user) }); if (count != 1) context.Fail("Session is no longer valid."); } }; });
builder.Services.Configure<Microsoft.AspNetCore.Http.Features.FormOptions>(o => o.MultipartBodyLengthLimit = 6 * 1024 * 1024); builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 6 * 1024 * 1024); builder.Services.AddAuthorization(); builder.Services.AddRateLimiter(o => { o.RejectionStatusCode = 429; o.AddPolicy("auth", c => RateLimitPartition.GetFixedWindowLimiter(c.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new() { PermitLimit = 15, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })); });
var app = builder.Build();
app.Use(async (c, next) => { c.Response.Headers["X-Content-Type-Options"] = "nosniff"; c.Response.Headers["Referrer-Policy"] = "no-referrer"; c.Response.Headers["X-Frame-Options"] = "DENY"; if (c.Request.Path.StartsWithSegments("/api")) c.Response.Headers.CacheControl = "no-store"; try { await next(); } catch (ApiError ex) { c.Response.StatusCode = ex.Status; await c.Response.WriteAsJsonAsync(new { error = ex.Message }); } catch (SqlException ex) { c.Response.StatusCode = ex.Number is 2601 or 2627 ? 409 : 400; await c.Response.WriteAsJsonAsync(new { error = ex.Number is 2601 or 2627 ? "This record already exists." : "The record could not be saved. Check required fields, linked records and allowed values." }); app.Logger.LogWarning("Database operation rejected: SQL error {Number}", ex.Number); } catch (Exception ex) when (ex is FormatException or ArgumentException) { c.Response.StatusCode = 400; await c.Response.WriteAsJsonAsync(new { error = "Invalid field format." }); } catch (Exception ex) { app.Logger.LogError(ex, "Request failed"); c.Response.StatusCode = 500; await c.Response.WriteAsJsonAsync(new { error = "Unable to complete the request. Please try again." }); } });
if (!app.Environment.IsDevelopment()) { app.UseHsts(); app.UseHttpsRedirection(); }
app.UseDefaultFiles(); app.UseStaticFiles(); app.UseRateLimiter(); app.UseAuthentication(); app.UseAuthorization(); app.MapAuth(); app.MapInvitations(); app.MapResources(); app.MapFeatures();
app.MapGet("/api/health", () => Results.Ok(new { status = "ok" }));
app.MapGet("/api/catalog", async (Db db) => { await using var c = await db.Open(); return Results.Ok(new { regions = await Db.Query(c, "SELECT Id,Name FROM cfg.Region ORDER BY Name"), cuisines = await Db.Query(c, "SELECT Id,Name,RegionId FROM cfg.Cuisine ORDER BY Name"), languages = await Db.Query(c, "SELECT l.Id,l.Code,p.NativeName,p.Direction FROM cfg.Language l JOIN cfg.LanguagePresentation p ON p.LanguageId=l.Id WHERE p.IsInterfaceEnabled=1") }); });
app.MapGet("/api/translations/{lang}", async (string lang, Db db) => { await using var c = await db.Open(); var rows = await Db.Query(c, "SELECT SourceText,DisplayText FROM cfg.fnInterfaceText(@l)", new() { ["l"] = lang }); return Results.Ok(rows.ToDictionary(x => (string)x["SourceText"]!, x => (string)x["DisplayText"]!)); });
app.MapGet("/api/bootstrap", async (ClaimsPrincipal u, Db db) => { await using var c = await db.Open(Db.Household(u)); return Results.Ok(new { userId = Db.User(u), household = (await Db.Query(c, "SELECT Id,Name,RegionId,DefaultCuisineId,CurrencyCode FROM family.Household"))[0], permissions = await Db.Query(c, "SELECT p.Code FROM family.Membership m JOIN auth.RolePermission r ON r.RoleId=m.RoleId JOIN auth.Permission p ON p.Id=r.PermissionId WHERE m.UserId=@u", new() { ["u"] = Db.User(u) }), menus = await Db.Query(c, "SELECT m.Id,m.Code,m.Label,m.Route,m.ParentId,p.Code Permission FROM cfg.Menu m LEFT JOIN auth.Permission p ON p.Id=m.PermissionId WHERE m.IsVisible=1 ORDER BY m.SortOrder"), options = await Db.Query(c, "SELECT o.Id,o.Label,o.Code,g.Code GroupCode FROM cfg.[Option] o JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE o.IsActive=1 ORDER BY o.SortOrder"), units = await Db.Query(c, "SELECT Id,Name,Code FROM cfg.Unit"), ingredients = await Db.Query(c, "SELECT i.Id,i.Name,i.DefaultUnitId,i.MediaId,p.CategoryCode,p.AccentColor FROM food.Ingredient i LEFT JOIN food.IngredientPresentation p ON p.IngredientId=i.Id WHERE i.IsActive=1"), allergens = await Db.Query(c, "SELECT Id,Name FROM food.Allergen"), categories = await Db.Query(c, "SELECT Id,Code,Name,Kind FROM finance.Category"), providers = await Db.Query(c, "SELECT Id,Name,Category,WebsiteUrl,ConnectionMode FROM commerce.Provider WHERE IsEnabled=1"), preferences = await Db.Query(c, "SELECT p.Id,p.Version,l.Code LanguageCode FROM family.InterfacePreference p JOIN cfg.Language l ON l.Id=p.LanguageId WHERE UserId=@u", new() { ["u"] = Db.User(u) }) }); }).RequireAuthorization();
app.MapGet("/media/{id:long}", async (long id, Db db) => { await using var c = await db.Open(); var rows = await Db.Query(c, "SELECT StorageKey,MimeType FROM cfg.MediaAsset WHERE Id=@id AND IsActive=1", new() { ["id"] = id }); if (rows.Count == 0) return Results.NotFound(); var root = Path.GetFullPath(app.Configuration["Media:Root"] ?? Path.Combine(app.Environment.ContentRootPath, "../database")) + Path.DirectorySeparatorChar; var path = Path.GetFullPath(Path.Combine(root, (string)rows[0]["StorageKey"]!)); if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !File.Exists(path)) return Results.NotFound(); return Results.File(path, (string)rows[0]["MimeType"]!); });
app.MapFallbackToFile("index.html");
app.Run();
