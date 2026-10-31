# Aarohi application

Local application implementation using ASP.NET Core 10, React 19, and SQL Server. The React build is served by the API on the same origin. This is a development implementation, not a completed production release.

## Run locally

### Visual Studio

Open `Aarohi.sln` in Visual Studio with .NET 10 SDK support and the ASP.NET/web development workload. Set `Aarohi.Api` as the startup project and select the `Aarohi` launch profile. React source, database scripts and setup files appear in solution folders; the React folder is a Vite application, not a separate MSBuild project.

Before pressing F5 for the first time (and after changing React files), run these commands from the solution directory in the Visual Studio terminal:

```powershell
npm ci --prefix ./web
npm run build --prefix ./web
```

Initialize the database as described below if needed. F5 starts the API and serves the compiled React app at http://127.0.0.1:5088. Stop any existing server using that port first. For React hot reload, run `npm run dev --prefix ./web` alongside the API and use the Vite address printed in the terminal. Building the solution builds the .NET project; it does not run npm automatically.

Prerequisites: .NET 10 SDK, Node.js 24, SQL Server or SQL Server LocalDB, and sqlcmd.

From this directory in PowerShell:

```powershell
# For a new local installation only:
sqllocaldb create AarohiSchemaTest
sqllocaldb start AarohiSchemaTest
./scripts/Initialize.ps1 -IncludeDemo
./scripts/Start.ps1
```

Open http://127.0.0.1:5088 and register your own household. The database in this workspace is already initialized; do not recreate it. Demo seeds are fictional and do not install a login password. To use another SQL instance/database, pass Server and Database to Initialize.ps1 and set ConnectionStrings__Aarohi before starting.

The development signing key is regenerated when the API restarts. Sessions are held in browser memory, so refreshing requires signing in again. Local email/password login does not verify email ownership.

## Implemented and tested

- Household registration, JWT sign-in/logout, one-time invitations, household switching, roles and permission checks.
- Family profiles, date of birth, health history, allergies, instructions, observations, prescriptions and private document uploads.
- Pantry lots, quantities, stock movements, configured low-stock/expiry rules, regional recipes and saved meal plans.
- Financial planning records, goal and retirement calculations, budgets, expense entry and spreadsheet export. Linked refunds reduce spending; transfers and credit-card payments do not count as new purchases.
- Configurable grocery and medicine provider listings, sample price comparison, saved shopping lists.
- Reminder configuration and language preferences for English, Spanish and Arabic, including RTL layout. Some new form labels still fall back to English.

Database scripts 001–013 are copied from the supplied schema package. Application extensions 014 and 015 add local credentials, household routing, recorded expenses and invitation tokens. All SQL uses server-defined resource mappings and parameterized values. Household session context, membership checks and clinical access checks are enforced by the API.

## Verification

```powershell
dotnet build ./api/Aarohi.Api.csproj
npm test --prefix ./web
npm run build --prefix ./web
# With the development server running and a disposable test database:
node ./tests/integration.mjs
```

Integration tests CREATE fictional households and records; they do not clean them up. Use a dedicated test database. See tests/integration-results.txt for the last passing run. Tests cover tenant isolation, permissions, stale updates, stock adjustment idempotency, refunds, private uploads, invitation reuse and revoked JWTs. Full browser/mobile acceptance testing remains pending; the preview disconnected during the final browser check.

## Pending work

- SMS OTP and Google authentication, account recovery and verified email flows.
- Live retailer/pharmacy APIs, real prices, availability, carts and checkout. Current offers are sample estimates; provider links are redirects only.
- Background reminder scheduling and SMS/email/push delivery.
- Malware scanning, secure document downloads, OCR and reviewed medical-document extraction. Uploaded files remain pending scan; no AI analysis occurs.
- Pantry-aware meal matching and clinically reviewed personalization. Current regional recipes and medical records do not constitute an automated medical diet engine.
- Weekly/monthly expense review summaries, complete localization and remaining configured pantry photographs.
- Full configuration administration for menus, pictures and reference data (currently maintained through SQL); production security review, accessibility/mobile acceptance tests and Azure deployment.

## Azure preparation

Run `./scripts/Publish.ps1` to build the combined application into artifacts/publish. The script copies public configured recipe assets. No deployment or Azure resources have been created.

Deployment configuration must supply:

| Setting | Purpose |
|---|---|
| ASPNETCORE_ENVIRONMENT=Production | Production runtime |
| ConnectionStrings__Aarohi | Azure SQL connection using encrypted transport and a dedicated identity |
| Jwt__PrivateKeyPath | Protected persistent RSA private-key PEM path; never publish a key with source |
| Jwt__Issuer / Jwt__Audience | Issuer and audience shared by token creation and validation |
| AllowedHosts | Your own application hostname |
| Media__Root | Published directory containing the assets folder |
| Documents__Root | Durable private storage outside the public web root |

Apply database migrations using a separate deployment identity. **Do not expose this development application publicly with its current privileged SQL account.** Registration currently uses IDENTITY_INSERT and needs redesign around narrowly permissioned stored procedures or equivalent provisioning before using a least-privilege production identity. The supplied baseline database role grants do not cover all new application objects. Complete those grants, persistent key management/rotation, private document storage/scanning, backups, monitoring, TLS/proxy configuration and security testing before production use. LocalDB and TrustServerCertificate are development settings only.

An Azure deployment can use your own hostname and does not require ChatGPT hosting or links. Hosting selection and deployment must be completed in your Azure subscription.

### Retailer product search
Enter a product on Shop & orders, then choose Search Blinkit, Search Zepto or Search BigBasket to pass the query to that retailer. Other providers use a clearly labelled Google site search. Medicine searches require manually entered terms and never include stored prescriptions or profiles automatically. Results remain external; no live price/stock retrieval or checkout is implemented. External search routes may change and may require location or sign-in; their end-to-end retailer behavior was not verified. Eight calculation/search tests and the React production build passed for this update.

### Reset a forgotten local password
From the aarohi-app directory, run in an interactive PowerShell or Command Prompt:

```powershell
dotnet run --project tools/PasswordReset/PasswordReset.csproj -- api/appsettings.Development.json
```
The utility displays the configured LocalDB server/database, asks for the registered email, and prompts twice for a new 12–128-character password. Password input is hidden (no dots). Type RESET when asked to commit. Escape at a password prompt cancels. It uses the same ASP.NET Core password hasher as sign-in, clears failed-login lockout, and revokes existing sessions in one transaction. No email is sent. Only local Windows-authenticated LocalDB connections are supported; this is a local administrator tool, not a public password-recovery endpoint. It does not create an account if registration never completed. No password should be passed on the command line or shared in chat.
