using System.Data;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;

// Local database administrator utility. Never exposed as an HTTP endpoint.
if (args.Length != 1 || Console.IsInputRedirected)
{
    Console.Error.WriteLine("Run interactively: dotnet run --project tools/PasswordReset -- api/appsettings.Development.json");
    return 1;
}
try
{
    using var config = JsonDocument.Parse(await File.ReadAllTextAsync(args[0]));
    var connection = new SqlConnectionStringBuilder(config.RootElement.GetProperty("ConnectionStrings").GetProperty("Aarohi").GetString());
    if (!connection.IntegratedSecurity || !connection.DataSource.StartsWith("(localdb)\\", StringComparison.OrdinalIgnoreCase))
        throw new InvalidOperationException("This utility supports Windows-authenticated LocalDB only.");
    Console.WriteLine($"Local password reset: {connection.DataSource} / {connection.InitialCatalog}");
    Console.Write("Registered email: ");
    var email = (Console.ReadLine() ?? "").Trim().ToLowerInvariant();
    if (!System.Net.Mail.MailAddress.TryCreate(email, out _) || email.Length > 254)
        throw new InvalidOperationException("Enter a valid registered email address.");

    await using var db = new SqlConnection(connection.ConnectionString);
    await db.OpenAsync();
    await using var lookup = new SqlCommand("SELECT u.Id FROM auth.UserAccount u JOIN auth.LocalCredential c ON c.UserId=u.Id WHERE u.EmailNormalized=@email AND u.Status='Active'", db);
    lookup.Parameters.Add("@email", SqlDbType.NVarChar, 254).Value = email;
    var found = await lookup.ExecuteScalarAsync();
    if (found is null || found is DBNull)
        throw new InvalidOperationException("No active password-login account found in this database. Check the email and database name. If registration never succeeded, register first.");
    var password = ReadPassword("New password (12–128 characters): ");
    var confirm = ReadPassword("Confirm new password: ");
    if (password.Length < 12 || password.Length > 128)
        throw new InvalidOperationException("Password must contain 12–128 characters. No changes made.");
    if (password != confirm)
        throw new InvalidOperationException("Passwords do not match. No changes made.");
    Console.Write("Type RESET to change this account's password and revoke its sessions: ");
    if (Console.ReadLine() != "RESET") { Console.WriteLine("Cancelled. No changes made."); return 0; }
    var hash = new PasswordHasher<string>().HashPassword(email, password);
    await using var tx = (SqlTransaction)await db.BeginTransactionAsync();
    await using var update = new SqlCommand("UPDATE c SET PasswordHash=@hash,FailedAttempts=0,LockedUntil=NULL FROM auth.LocalCredential c JOIN auth.UserAccount u ON u.Id=c.UserId WHERE c.UserId=@id AND u.Status='Active';", db, tx);
    update.Parameters.Add("@hash", SqlDbType.NVarChar, 500).Value = hash;
    update.Parameters.Add("@id", SqlDbType.BigInt).Value = Convert.ToInt64(found);
    if (await update.ExecuteNonQueryAsync() != 1)
        throw new InvalidOperationException("Account changed during reset. No changes saved.");
    await using var revoke = new SqlCommand("UPDATE auth.Session SET RevokedAt=SYSUTCDATETIME(),RevocationReason='Local administrator password reset' WHERE UserId=@id AND RevokedAt IS NULL", db, tx);
    revoke.Parameters.Add("@id", SqlDbType.BigInt).Value = Convert.ToInt64(found);
    await revoke.ExecuteNonQueryAsync();
    await tx.CommitAsync();
    Console.WriteLine("Password reset complete. Sign in with your new password. No email is sent.");
    return 0;
}
catch (SqlException ex)
{
    Console.Error.WriteLine($"Database reset failed (SQL {ex.Number}). Check the selected database, migrations 014/015, and your Windows database permissions. No successful reset was confirmed.");
    return 1;
}
catch (Exception ex) when (ex is InvalidOperationException or IOException or JsonException or KeyNotFoundException or ArgumentException)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

static string ReadPassword(string prompt)
{
    Console.Write(prompt);
    var text = new StringBuilder();
    while (true)
    {
        var key = Console.ReadKey(intercept: true);
        if (key.Key == ConsoleKey.Enter) { Console.WriteLine(); return text.ToString(); }
        if (key.Key == ConsoleKey.Escape) throw new InvalidOperationException("Cancelled. No changes made.");
        if (key.Key == ConsoleKey.Backspace) { if (text.Length > 0) text.Length--; continue; }
        if (!char.IsControl(key.KeyChar)) text.Append(key.KeyChar);
    }
}
