using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.Data.SqlClient;
namespace Aarohi;

public sealed class TokenService
{
    public RsaSecurityKey Key { get; }
    public TokenService(IConfiguration cfg, IHostEnvironment env) { var rsa = RSA.Create(3072); var path = cfg["Jwt:PrivateKeyPath"]; if (path != null) rsa.ImportFromPem(File.ReadAllText(path)); else if (!env.IsDevelopment()) throw new InvalidOperationException("Set Jwt__PrivateKeyPath to a secured RSA PEM key in production."); Key = new RsaSecurityKey(rsa); }
    public string Issue(long user, long household, long session) => new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken("aarohi-api", "aarohi-web", [new("uid", user.ToString()), new("hid", household.ToString()), new("sid", session.ToString()), new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())], expires: DateTime.UtcNow.AddMinutes(30), signingCredentials: new(Key, SecurityAlgorithms.RsaSha256)));
}
public record RegisterRequest(string Name, string Email, string Password, string HouseholdName, long RegionId, long CuisineId, DateTime BirthDate);
public record LoginRequest(string Email, string Password);
public static class AuthEndpoints
{
    static readonly PasswordHasher<string> Hasher = new();
    const string DevelopmentAdminEmail = "admin@aarohi.local";

    static string DevelopmentAdminPassword => Environment.GetEnvironmentVariable("AAROHI_DEV_ADMIN_PASSWORD") ?? throw new ApiError(401, "Development admin password is not configured. Set AAROHI_DEV_ADMIN_PASSWORD before starting the app.");

    static async Task<(long UserId, long HouseholdId)> EnsureDevelopmentAdminAsync(SqlConnection c)
    {
        var existingUser = await Db.Query(c, "SELECT Id FROM auth.UserAccount WHERE EmailNormalized=@e", new() { ["e"] = DevelopmentAdminEmail });
        if (existingUser.Count > 0)
        {
            var userId = Convert.ToInt64(existingUser[0]["Id"]);
            var existingHome = await Db.Query(c, "SELECT HouseholdId FROM auth.UserHousehold WHERE UserId=@u", new() { ["u"] = userId });
            if (existingHome.Count > 0)
            {
                return (userId, Convert.ToInt64(existingHome[0]["HouseholdId"]));
            }

            var regionId = await Db.Scalar(c, "SELECT TOP (1) Id FROM cfg.Region WHERE IsActive=1 ORDER BY Id");
            var cuisineId = await Db.Scalar(c, "SELECT TOP (1) Id FROM cfg.Cuisine WHERE RegionId=@regionId AND IsActive=1 ORDER BY Id", new() { ["regionId"] = regionId });
            var householdId = await Db.Scalar(c, "SELECT CONVERT(bigint,ISNULL(IDENT_CURRENT('family.Household'),0))+1");
            await Db.Exec(c, "EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=@householdId; SET IDENTITY_INSERT family.Household ON; INSERT family.Household(Id,Name,RegionId,DefaultCuisineId,LanguageId,ThemeId) VALUES(@householdId,@name,@regionId,@cuisineId,1,1); SET IDENTITY_INSERT family.Household OFF; INSERT family.Membership(HouseholdId,UserId,RoleId) SELECT @householdId,@userId,Id FROM auth.Role WHERE Code='admin'; INSERT auth.UserHousehold VALUES(@userId,@householdId); INSERT family.Member(HouseholdId,Name,BirthDate,Relationship,UserId) VALUES(@householdId,@person,@birth,'Self',@userId);", new() { ["householdId"] = householdId, ["name"] = "Admin Household", ["regionId"] = regionId, ["cuisineId"] = cuisineId, ["userId"] = userId, ["person"] = "Admin", ["birth"] = new DateTime(1990, 1, 1) });
            return (userId, householdId);
        }

        var roleId = await Db.Scalar(c, "SELECT Id FROM auth.Role WHERE Code='admin'");
        var regionIdNew = await Db.Scalar(c, "SELECT TOP (1) Id FROM cfg.Region WHERE IsActive=1 ORDER BY Id");
        var cuisineIdNew = await Db.Scalar(c, "SELECT TOP (1) Id FROM cfg.Cuisine WHERE RegionId=@regionId AND IsActive=1 ORDER BY Id", new() { ["regionId"] = regionIdNew });
        var householdIdNew = await Db.Scalar(c, "SELECT CONVERT(bigint,ISNULL(IDENT_CURRENT('family.Household'),0))+1");
        var userIdNew = await Db.Scalar(c, "INSERT auth.UserAccount(DisplayName,EmailNormalized,Status) OUTPUT inserted.Id VALUES(@name,@email,'Active')", new() { ["name"] = "Admin", ["email"] = DevelopmentAdminEmail });
        await Db.Exec(c, "INSERT auth.LocalCredential(UserId,PasswordHash) VALUES(@userId,@passwordHash)", new() { ["userId"] = userIdNew, ["passwordHash"] = Hasher.HashPassword(DevelopmentAdminEmail, DevelopmentAdminPassword) });
        await Db.Exec(c, "EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=@householdId; SET IDENTITY_INSERT family.Household ON; INSERT family.Household(Id,Name,RegionId,DefaultCuisineId,LanguageId,ThemeId) VALUES(@householdId,@name,@regionId,@cuisineId,1,1); SET IDENTITY_INSERT family.Household OFF; INSERT family.Membership(HouseholdId,UserId,RoleId) VALUES(@householdId,@userId,@roleId); INSERT auth.UserHousehold VALUES(@userId,@householdId); INSERT family.Member(HouseholdId,Name,BirthDate,Relationship,UserId) VALUES(@householdId,@person,@birth,'Self',@userId);", new() { ["householdId"] = householdIdNew, ["name"] = "Admin Household", ["regionId"] = regionIdNew, ["cuisineId"] = cuisineIdNew, ["userId"] = userIdNew, ["roleId"] = roleId, ["person"] = "Admin", ["birth"] = new DateTime(1990, 1, 1) });
        return (userIdNew, householdIdNew);
    }

    public static void MapAuth(this WebApplication app)
    {
        app.MapPost("/api/auth/register", async (RegisterRequest r, Db db, TokenService tokens) =>
        {
            if (string.IsNullOrWhiteSpace(r.Name) || r.Name.Length > 120 || string.IsNullOrWhiteSpace(r.HouseholdName) || r.HouseholdName.Length > 150 || !System.Net.Mail.MailAddress.TryCreate(r.Email, out _) || r.Email.Length > 254 || r.Password.Length < 12 || r.Password.Length > 128 || r.BirthDate > DateTime.UtcNow.AddYears(-18) || r.BirthDate < DateTime.UtcNow.AddYears(-120)) throw new ApiError(400, "Enter valid details. Account holders must be 18 or older; use a password of 12–128 characters.");
            await using var c = await db.Open(); await using var tx = (SqlTransaction)await c.BeginTransactionAsync();
            // A transaction-owned lock serializes identity reservation across registrations.
            await Db.Exec(c, "DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource='aarohi-registration',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000; IF @lock<0 THROW 52400,'Registration busy; retry',1;", tx: tx);
            var h = await Db.Scalar(c, "SELECT CONVERT(bigint,ISNULL(IDENT_CURRENT('family.Household'),0))+1", tx: tx);
            var u = await Db.Scalar(c, "INSERT auth.UserAccount(DisplayName,EmailNormalized,Status) OUTPUT inserted.Id VALUES(@n,@e,'Active')", new() { ["n"] = r.Name.Trim(), ["e"] = r.Email.Trim().ToLowerInvariant() }, tx);
            await Db.Exec(c, "INSERT auth.LocalCredential(UserId,PasswordHash) VALUES(@u,@p)", new() { ["u"] = u, ["p"] = Hasher.HashPassword(r.Email, r.Password) }, tx);
            await Db.Exec(c, "EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=@h; SET IDENTITY_INSERT family.Household ON; INSERT family.Household(Id,Name,RegionId,DefaultCuisineId,LanguageId,ThemeId) VALUES(@h,@n,@r,@c,1,1); SET IDENTITY_INSERT family.Household OFF; INSERT family.Membership(HouseholdId,UserId,RoleId) SELECT @h,@u,Id FROM auth.Role WHERE Code='admin'; INSERT auth.UserHousehold VALUES(@u,@h); INSERT family.Member(HouseholdId,Name,BirthDate,Relationship,UserId) VALUES(@h,@person,@birth,'Self',@u);", new() { ["h"] = h, ["u"] = u, ["n"] = r.HouseholdName.Trim(), ["r"] = r.RegionId, ["c"] = r.CuisineId, ["person"] = r.Name.Trim(), ["birth"] = r.BirthDate.Date }, tx);
            await tx.CommitAsync(); return Results.Ok(await Session(c, u, h, tokens));
        }).RequireRateLimiting("auth");
        app.MapPost("/api/auth/login", async (LoginRequest r, Db db, TokenService tokens) =>
        {
            if (r.Email.Length > 254 || r.Password.Length > 128) throw new ApiError(401, "Invalid credentials.");

            var enteredEmail = r.Email.Trim();
            var useDevelopmentAdmin = app.Environment.IsDevelopment() && (string.Equals(enteredEmail, "admin", StringComparison.OrdinalIgnoreCase) || string.Equals(enteredEmail, DevelopmentAdminEmail, StringComparison.OrdinalIgnoreCase));
            var normalizedEmail = useDevelopmentAdmin ? DevelopmentAdminEmail : enteredEmail;

            await using var c = await db.Open();
            if (useDevelopmentAdmin && string.Equals(r.Password, DevelopmentAdminPassword, StringComparison.Ordinal))
            {
                var admin = await EnsureDevelopmentAdminAsync(c);
                return Results.Ok(await Session(c, admin.UserId, admin.HouseholdId, tokens));
            }

            var rows = await Db.Query(c, "SELECT u.Id,u.Status,l.PasswordHash,l.FailedAttempts,l.LockedUntil FROM auth.UserAccount u JOIN auth.LocalCredential l ON l.UserId=u.Id WHERE u.EmailNormalized=@e", new() { ["e"] = normalizedEmail.ToLowerInvariant() });
            if (rows.Count == 0) { Hasher.VerifyHashedPassword("dummy", Hasher.HashPassword("dummy", "not-a-valid-account-password"), r.Password); throw new ApiError(401, "Invalid credentials."); }
            var user = rows[0]; var uid = Convert.ToInt64(user["Id"]); if ((string?)user["Status"] != "Active" || user["LockedUntil"] is DateTime locked && locked > DateTime.UtcNow) throw new ApiError(401, "Invalid credentials or account temporarily locked.");
            if (Hasher.VerifyHashedPassword(normalizedEmail, (string)user["PasswordHash"]!, r.Password) == PasswordVerificationResult.Failed) { await Db.Exec(c, "UPDATE auth.LocalCredential SET FailedAttempts=FailedAttempts+1,LockedUntil=CASE WHEN FailedAttempts>=4 THEN DATEADD(minute,15,SYSUTCDATETIME()) ELSE NULL END WHERE UserId=@u", new() { ["u"] = uid }); throw new ApiError(401, "Invalid credentials."); }
            await Db.Exec(c, "UPDATE auth.LocalCredential SET FailedAttempts=0,LockedUntil=NULL WHERE UserId=@u", new() { ["u"] = uid });
            var homes = await Db.Query(c, "SELECT HouseholdId FROM auth.UserHousehold WHERE UserId=@u", new() { ["u"] = uid });
            foreach (var home in homes) { var hid = Convert.ToInt64(home["HouseholdId"]); await Db.Exec(c, "EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=@h", new() { ["h"] = hid }); if (await Db.Scalar(c, "SELECT COUNT(*) FROM family.Membership WHERE UserId=@u AND Status='Active'", new() { ["u"] = uid }) > 0) return Results.Ok(await Session(c, uid, hid, tokens)); }
            throw new ApiError(403, "No active household membership.");
        }).RequireRateLimiting("auth");
        app.MapPost("/api/auth/logout", async (ClaimsPrincipal user, Db db) => { await using var c = await db.Open(); await Db.Exec(c, "UPDATE auth.Session SET RevokedAt=SYSUTCDATETIME(),RevocationReason='Signed out' WHERE Id=@s AND UserId=@u", new() { ["s"] = long.Parse(user.FindFirstValue("sid")!), ["u"] = Db.User(user) }); return Results.NoContent(); }).RequireAuthorization();
    }
    internal static async Task<object> Session(SqlConnection c, long u, long h, TokenService tokens) { var sid = await Db.Scalar(c, "INSERT auth.Session(UserId,TokenPolicyId,DeviceLabel,ExpiresAt) OUTPUT inserted.Id SELECT @u,Id,'Aarohi web',DATEADD(minute,30,SYSUTCDATETIME()) FROM auth.TokenPolicy WHERE Code='aarohi-web'", new() { ["u"] = u }); return new { accessToken = tokens.Issue(u, h, sid), expiresIn = 1800 }; }
}
