using System.Globalization;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
namespace Aarohi;

public record StockAdjustment(decimal QuantityDelta, Guid IdempotencyKey);
public record PreferenceRequest(string LanguageCode);
public record RoleRequest(long RoleId, string Status);

public sealed record SearchRoute(string Url, string Param);

public static partial class LivePriceLookup
{
    private static readonly Regex PriceRegex = new(@"(?:₹|INR|Rs\.?|Rs\s*)\s*(\d+(?:[.,]\d{1,2})?)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    private static readonly Dictionary<string, SearchRoute> SearchRoutes = new(StringComparer.OrdinalIgnoreCase)
    {
        ["blinkit.com"] = new("https://blinkit.com/search", "q"),
        ["bigbasket.com"] = new("https://www.bigbasket.com/ps/", "q"),
        ["zeptonow.com"] = new("https://www.zepto.com/search", "query"),
        ["zepto.com"] = new("https://www.zepto.com/search", "query")
    };

    public static async Task<List<Dictionary<string, object?>>> GetLatestOffersAsync(IHttpClientFactory httpFactory, List<Dictionary<string, object?>> products, List<Dictionary<string, object?>> providers, CancellationToken cancellationToken = default)
    {
        if (products.Count == 0 || providers.Count == 0) return [];

        var client = httpFactory.CreateClient("aarohi-price-fetcher");
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (compatible; AarohiPriceBot/1.0)");
        client.Timeout = TimeSpan.FromSeconds(12);

        var offers = new List<Dictionary<string, object?>>();
        foreach (var product in products)
        {
            var name = product.TryGetValue("Name", out var rawName) ? rawName?.ToString()?.Trim() : null;
            if (string.IsNullOrWhiteSpace(name)) continue;

            foreach (var provider in providers)
            {
                var providerName = provider.TryGetValue("Name", out var rawProviderName) ? rawProviderName?.ToString() : null;
                if (string.IsNullOrWhiteSpace(providerName)) continue;

                var url = BuildSearchUrl(provider, name);
                if (url is null) continue;

                try
                {
                    using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
                    if (!response.IsSuccessStatusCode) continue;

                    var html = await response.Content.ReadAsStringAsync(cancellationToken);
                    var price = ExtractPrice(html);
                    if (price is null) continue;

                    offers.Add(new Dictionary<string, object?>
                    {
                        ["ProductId"] = product["Id"],
                        ["ProviderId"] = provider["Id"],
                        ["CurrencyCode"] = "INR",
                        ["PackPrice"] = price,
                        ["SourceUrl"] = url,
                        ["RetrievedAt"] = DateTime.UtcNow,
                    });
                }
                catch
                {
                    // Ignore transient network issues and fall back to any seeded demo offer.
                }
            }
        }

        return offers;
    }

    private static string? BuildSearchUrl(Dictionary<string, object?> provider, string productName)
    {
        var website = provider.TryGetValue("WebsiteUrl", out var rawWebsite) ? rawWebsite?.ToString() : null;
        if (string.IsNullOrWhiteSpace(website)) return null;

        if (!Uri.TryCreate(website, UriKind.Absolute, out var site)) return null;

        var host = site.Host.Replace("www.", string.Empty, StringComparison.OrdinalIgnoreCase);
        var route = SearchRoutes.TryGetValue(host, out var match) ? match : new SearchRoute("https://www.google.com/search", "q");
        var safeSearch = productName.Replace("&", " ").Replace("+", " ").Trim();
        if (string.IsNullOrWhiteSpace(safeSearch)) return null;

        var encodedSearch = Uri.EscapeDataString(safeSearch);
        var separator = route.Url.Contains('?') ? '&' : '?';
        return $"{route.Url}{separator}{Uri.EscapeDataString(route.Param)}={encodedSearch}";
    }

    private static decimal? ExtractPrice(string html)
    {
        var matches = PriceRegex.Matches(html);
        if (matches.Count == 0) return null;

        foreach (Match match in matches)
        {
            var raw = match.Groups[1].Value.Replace(",", "").Trim();
            if (decimal.TryParse(raw, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var price) && price > 0 && price <= 200000)
            {
                return Math.Round(price, 2);
            }
        }

        return null;
    }

    internal static bool TryConvertToLong(object? value, out long result)
    {
        if (value is null)
        {
            result = 0;
            return false;
        }

        if (value is long l)
        {
            result = l;
            return true;
        }

        if (value is int i)
        {
            result = i;
            return true;
        }

        if (value is short s)
        {
            result = s;
            return true;
        }

        if (value is byte b)
        {
            result = b;
            return true;
        }

        if (value is decimal d)
        {
            result = (long)Math.Round(d, MidpointRounding.AwayFromZero);
            return true;
        }

        return long.TryParse(value.ToString(), out result);
    }
}

public static class Features
{
    public static void MapFeatures(this WebApplication app)
    {
        app.MapGet("/api/pantry", async (Db db, ClaimsPrincipal u) => { await Resources.Guard(db, u, "pantry.read"); await using var c = await db.Open(Db.Household(u)); return Results.Ok(new { lots = await Db.Query(c, "SELECT b.*,i.Name,i.MediaId,p.AccentColor,p.CategoryCode,u.Code Unit FROM pantry.vLotBalance b JOIN food.Ingredient i ON i.Id=b.IngredientId JOIN cfg.Unit u ON u.Id=b.UnitId LEFT JOIN food.IngredientPresentation p ON p.IngredientId=i.Id"), alerts = await Db.Query(c, "SELECT * FROM pantry.fnAlerts(CONVERT(date,DATEADD(minute,330,SYSUTCDATETIME())))") }); }).RequireAuthorization();
        app.MapPost("/api/pantry/{id:long}/adjust", async (long id, StockAdjustment r, Db db, ClaimsPrincipal u) => { await Resources.Guard(db, u, "pantry.write"); if (r.QuantityDelta == 0 || Math.Abs(r.QuantityDelta) > 100000 || r.IdempotencyKey == Guid.Empty) throw new ApiError(400, "Enter a valid quantity change."); await using var c = await db.Open(Db.Household(u)); await Db.Exec(c, "IF NOT EXISTS(SELECT 1 FROM pantry.Movement WHERE HouseholdId=@h AND IdempotencyKey=@key) INSERT pantry.Movement(HouseholdId,StockLotId,QuantityDelta,ReasonOptionId,OccurredAt,IdempotencyKey,RecordedByUserId) SELECT @h,@lot,@q,o.Id,SYSUTCDATETIME(),@key,@u FROM cfg.[Option] o JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code='StockReason' AND o.Code='adjustment'", new() { ["h"] = Db.Household(u), ["lot"] = id, ["q"] = r.QuantityDelta, ["key"] = r.IdempotencyKey, ["u"] = Db.User(u) }); return Results.NoContent(); }).RequireAuthorization();
        app.MapGet("/api/recipes", async (long? region, Db db, ClaimsPrincipal u) => { await Resources.Guard(db, u, "household.read"); await using var c = await db.Open(Db.Household(u)); return Results.Ok(await Db.Query(c, "SELECT DISTINCT r.Id,r.Name,r.MediaId,r.Servings,r.PrepMinutes,r.IndicativeCostINR,r.Instructions,r.IsPlaceholder,r.ReviewStatus FROM food.Recipe r JOIN food.RecipeCuisine rc ON rc.RecipeId=r.Id JOIN cfg.Cuisine c ON c.Id=rc.CuisineId WHERE (@r IS NULL OR c.RegionId=@r)", new() { ["r"] = region })); }).RequireAuthorization();
        app.MapPost("/api/preferences", async (PreferenceRequest r, ClaimsPrincipal u, Db db) => { await using var c = await db.Open(Db.Household(u)); await Db.Exec(c, "DECLARE @l bigint=(SELECT l.Id FROM cfg.Language l JOIN cfg.LanguagePresentation p ON p.LanguageId=l.Id WHERE l.Code=@code AND p.IsInterfaceEnabled=1); IF @l IS NULL THROW 52401,'Unsupported language',1; UPDATE family.InterfacePreference SET LanguageId=@l WHERE HouseholdId=@h AND UserId=@u; IF @@ROWCOUNT=0 INSERT family.InterfacePreference(HouseholdId,UserId,LanguageId) VALUES(@h,@u,@l);", new() { ["h"] = Db.Household(u), ["u"] = Db.User(u), ["code"] = r.LanguageCode }); return Results.NoContent(); }).RequireAuthorization();
        app.MapGet("/api/finance/overview", async (ClaimsPrincipal u, Db db) => { await Resources.Guard(db, u, "finance.read"); await using var c = await db.Open(Db.Household(u)); return Results.Ok(new { scenarios = await Db.Query(c, "SELECT * FROM finance.vPlanOverview"), spending = await Db.Query(c, "SELECT OccurredOn,Category,SUM(NetSpent) Amount FROM finance.vRecordedSpending GROUP BY OccurredOn,Category"), goals = await Db.Query(c, "SELECT g.Id,g.Name,g.TargetAmount,g.OpeningSavedAmount+COALESCE(SUM(CASE WHEN e.Kind='Savings transfer' THEN e.Amount WHEN e.Kind='Savings withdrawal' THEN -e.Amount END),0) Saved FROM finance.SavingsGoal g LEFT JOIN finance.ExpenseEntry e ON e.HouseholdId=g.HouseholdId AND e.GoalId=g.Id GROUP BY g.Id,g.Name,g.TargetAmount,g.OpeningSavedAmount") }); }).RequireAuthorization();
        app.MapGet("/api/comparison", async (IHttpClientFactory httpFactory, Db db, ClaimsPrincipal u) => { await Resources.Guard(db, u, "shopping.manage"); await using var c = await db.Open(); var products = await Db.Query(c, "SELECT * FROM commerce.DemoProduct"); var offers = await Db.Query(c, "SELECT * FROM commerce.DemoOffer"); var online = await LivePriceLookup.GetLatestOffersAsync(httpFactory, products, await Db.Query(c, "SELECT Id,Name,Category,WebsiteUrl FROM commerce.Provider WHERE IsEnabled=1"));
            var merged = new List<Dictionary<string, object?>>();
            foreach (var offer in offers) merged.Add(new Dictionary<string, object?>(offer));
            foreach (var offer in online)
            {
                if (!LivePriceLookup.TryConvertToLong(offer["ProductId"], out var productId) || !LivePriceLookup.TryConvertToLong(offer["ProviderId"], out var providerId)) continue;
                var existing = merged.FirstOrDefault(x => LivePriceLookup.TryConvertToLong(x["ProductId"], out var existingProductId) && LivePriceLookup.TryConvertToLong(x["ProviderId"], out var existingProviderId) && existingProductId == productId && existingProviderId == providerId);
                if (existing is null) { merged.Add(new Dictionary<string, object?>(offer)); continue; }
                merged.Remove(existing);
                merged.Add(new Dictionary<string, object?>(offer));
            }
            return Results.Ok(new { products, offers = merged });
        }).RequireAuthorization();
        app.MapGet("/api/users", async (Db db, ClaimsPrincipal u) => { await Resources.Guard(db, u, "users.manage"); await using var c = await db.Open(Db.Household(u)); return Results.Ok(new { users = await Db.Query(c, "SELECT m.UserId,u.DisplayName,m.RoleId,r.Name Role,m.Status FROM family.Membership m JOIN auth.UserAccount u ON u.Id=m.UserId JOIN auth.Role r ON r.Id=m.RoleId"), roles = await Db.Query(c, "SELECT Id,Name FROM auth.Role WHERE IsActive=1") }); }).RequireAuthorization();
        app.MapPut("/api/users/{id:long}", async (long id, RoleRequest r, Db db, ClaimsPrincipal u) => { await Resources.Guard(db, u, "users.manage"); if (r.Status is not ("Active" or "Disabled")) throw new ApiError(400, "Unsupported membership status."); await using var c = await db.Open(Db.Household(u)); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(System.Data.IsolationLevel.Serializable); var count = await Db.Scalar(c, "SELECT COUNT(*) FROM family.Membership WITH(UPDLOCK,HOLDLOCK) WHERE UserId<>@u AND Status='Active' AND RoleId=(SELECT Id FROM auth.Role WHERE Code='admin')", new() { ["u"] = id }, tx); var admin = await Db.Scalar(c, "SELECT Id FROM auth.Role WHERE Code='admin'", tx: tx); if (count == 0 && (r.Status != "Active" || r.RoleId != admin)) throw new ApiError(400, "Keep at least one active administrator."); await Db.Exec(c, "UPDATE family.Membership SET RoleId=@r,Status=@s WHERE UserId=@id", new() { ["r"] = r.RoleId, ["s"] = r.Status, ["id"] = id }, tx); await tx.CommitAsync(); return Results.NoContent(); }).RequireAuthorization();
        app.MapGet("/api/documents", async (Db db, ClaimsPrincipal u) => { await Resources.Guard(db, u, "health.documents"); await using var c = await db.Open(Db.Household(u)); return Results.Ok(await Db.Query(c, "SELECT Id,MemberId,OriginalName,CategoryOptionId,ByteLength,ScanStatus,ReviewStatus,CreatedAt FROM health.Document WHERE DeletedAt IS NULL AND " + Db.MemberAccess.Replace("health.read", "health.documents"), new() { ["actor"] = Db.User(u) })); }).RequireAuthorization();
        app.MapPost("/api/documents", async (HttpRequest request, ClaimsPrincipal u, Db db, IConfiguration cfg) => { await Resources.Guard(db, u, "health.documents"); if (request.ContentLength > 6 * 1024 * 1024) throw new ApiError(400, "File limit is 5 MB."); var form = await request.ReadFormAsync(); var file = form.Files.GetFile("file") ?? throw new ApiError(400, "Choose a file."); if (file.Length == 0 || file.Length > 5 * 1024 * 1024) throw new ApiError(400, "File limit is 5 MB."); long member = long.Parse(form["memberId"].ToString()), category = long.Parse(form["categoryId"].ToString()); await using var c = await db.Open(Db.Household(u)); if (await Db.Scalar(c, "SELECT COUNT(*) FROM family.Member WHERE Id=@m AND (UserId=@actor OR Id IN(SELECT MemberId FROM family.MemberAccess WHERE UserId=@actor AND PermissionId IN(SELECT Id FROM auth.Permission WHERE Code='health.documents') AND RevokedAt IS NULL AND (ExpiresAt IS NULL OR ExpiresAt>SYSUTCDATETIME())))", new() { ["m"] = member, ["actor"] = Db.User(u) }) == 0) throw new ApiError(403, "Health profile access required."); using var ms = new MemoryStream(); await file.CopyToAsync(ms); var bytes = ms.ToArray(); string? mime = bytes.AsSpan().StartsWith("%PDF-"u8) ? "application/pdf" : bytes.AsSpan().StartsWith(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }) ? "image/png" : bytes.Length > 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255 ? "image/jpeg" : null; if (mime == null) throw new ApiError(400, "Upload a PDF, PNG or JPEG."); var root = Path.GetFullPath(cfg["Documents:Root"] ?? "App_Data/documents"); Directory.CreateDirectory(root); var key = Guid.NewGuid().ToString("N"); var path = Path.Combine(root, key); await File.WriteAllBytesAsync(path, bytes); try { var id = await Db.Scalar(c, "INSERT health.Document(HouseholdId,MemberId,CategoryOptionId,OriginalName,StorageKey,MimeType,ByteLength,Sha256,UploadedByUserId) OUTPUT inserted.Id VALUES(@h,@m,@cat,@name,@key,@mime,@len,@hash,@u)", new() { ["h"] = Db.Household(u), ["m"] = member, ["cat"] = category, ["name"] = Path.GetFileName(file.FileName), ["key"] = key, ["mime"] = mime, ["len"] = bytes.Length, ["hash"] = SHA256.HashData(bytes), ["u"] = Db.User(u) }); return Results.Ok(new { id, message = "Stored privately, awaiting malware scan. Downloads and AI analysis are not enabled." }); } catch { File.Delete(path); throw; } }).RequireAuthorization().DisableAntiforgery();
    }
}
