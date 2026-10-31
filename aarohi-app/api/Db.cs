using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Claims;
namespace Aarohi;

public sealed class Db(IConfiguration config)
{
    public async Task<SqlConnection> Open(long? household = null) { var c = new SqlConnection(config.GetConnectionString("Aarohi") ?? throw new InvalidOperationException("Configure ConnectionStrings__Aarohi")); await c.OpenAsync(); await Exec(c, "EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=@h", new() { ["h"] = household }); return c; }
    public static SqlCommand Command(SqlConnection c, string sql, Dictionary<string, object?>? values = null, SqlTransaction? tx = null) { if (sql.Contains("OUTPUT inserted.Id", StringComparison.OrdinalIgnoreCase)) { sql = "DECLARE @Captured TABLE(Id bigint); " + sql.Replace("OUTPUT inserted.Id", "OUTPUT inserted.Id INTO @Captured", StringComparison.OrdinalIgnoreCase) + "; SELECT Id FROM @Captured;"; } var cmd = new SqlCommand(sql, c, tx); if (values != null) foreach (var (k, v) in values) cmd.Parameters.AddWithValue("@" + k, v ?? DBNull.Value); return cmd; }
    public static async Task<List<Dictionary<string, object?>>> Query(SqlConnection c, string sql, Dictionary<string, object?>? values = null, SqlTransaction? tx = null) { await using var cmd = Command(c, sql, values, tx); await using var reader = await cmd.ExecuteReaderAsync(); var rows = new List<Dictionary<string, object?>>(); while (await reader.ReadAsync()) { var row = new Dictionary<string, object?>(); for (int i = 0; i < reader.FieldCount; i++) row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i); rows.Add(row); } return rows; }
    public static async Task<int> Exec(SqlConnection c, string sql, Dictionary<string, object?>? values = null, SqlTransaction? tx = null) { await using var cmd = Command(c, sql, values, tx); return await cmd.ExecuteNonQueryAsync(); }
    public static async Task<long> Scalar(SqlConnection c, string sql, Dictionary<string, object?>? values = null, SqlTransaction? tx = null) { await using var cmd = Command(c, sql, values, tx); return Convert.ToInt64(await cmd.ExecuteScalarAsync()); }
    public static long User(ClaimsPrincipal u) => long.Parse(u.FindFirstValue("uid") ?? throw new UnauthorizedAccessException());
    public static long Household(ClaimsPrincipal u) => long.Parse(u.FindFirstValue("hid") ?? throw new UnauthorizedAccessException());
    public async Task<bool> Permission(ClaimsPrincipal user, string code) { await using var c = await Open(Household(user)); return await Scalar(c, "SELECT COUNT(*) FROM family.Membership m JOIN auth.RolePermission rp ON rp.RoleId=m.RoleId JOIN auth.Permission p ON p.Id=rp.PermissionId WHERE m.UserId=@u AND m.Status='Active' AND p.Code=@p", new() { ["u"] = User(user), ["p"] = code }) > 0; }
    public const string MemberAccess = "(MemberId IN (SELECT Id FROM family.Member WHERE UserId=@actor) OR MemberId IN (SELECT MemberId FROM family.MemberAccess WHERE UserId=@actor AND PermissionId IN(SELECT Id FROM auth.Permission WHERE Code='health.read') AND RevokedAt IS NULL AND (ExpiresAt IS NULL OR ExpiresAt>SYSUTCDATETIME())))";
}
public sealed class ApiError(int status, string message) : Exception(message) { public int Status { get; } = status; }
