# PersonalHealthAssist — Aarohi

Family health, home pantry, regional meal planning, shopping links and personal budgeting built with **ASP.NET Core 10, React 19 and SQL Server**.

Open [aarohi-app/Aarohi.sln](aarohi-app/Aarohi.sln) in Visual Studio with .NET 10 support. Read the [application setup guide](aarohi-app/README.md) for database installation, React build, local startup, password reset and deployment preparation.

## Source layout

- `aarohi-app/api`: .NET API, JWT authentication and household access checks.
- `aarohi-app/web`: React/Vite frontend.
- `aarohi-app/database`: SQL Server migrations 001–015, fictional seed data and public food images.
- `aarohi-app/tests`: calculation, search-link and HTTP integration checks.
- `aarohi-app/scripts`: database installation, startup and publish scripts.
- `aarohi-app/tools/PasswordReset`: interactive local account recovery utility.

## Start locally

Install .NET 10 SDK, Node.js 24, SQL Server LocalDB and sqlcmd. From `aarohi-app`:

```powershell
# New installation only:
sqllocaldb create AarohiSchemaTest
sqllocaldb start AarohiSchemaTest
./scripts/Initialize.ps1 -IncludeDemo
./scripts/Start.ps1
```

Open http://127.0.0.1:5088 and register a household. The checked-in development connection uses Windows authentication, with no database password. Configure your own local server/database as necessary. All migrations through 015 are required for registration and invitations.

## Current status

This is a development implementation, not a production release. Retailer searches open external websites; live prices, cart transfer and ordering are not connected. SMS/Google authentication, delivered notifications, medical-document scanning/AI analysis and automated clinical meal personalization remain pending. See the application guide for the complete limitations and Azure security work required before public hosting.

Private uploads, database files, credentials, dependencies and build output are excluded from the repository. No real family or medical records are included in the seed scripts. Integration tests create fictional records and should run only against a disposable test database.
