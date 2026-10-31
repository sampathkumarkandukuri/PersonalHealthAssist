# Aarohi — SQL Server database package

Database schema and fictional test data for the approved Aarohi wireframe. No frontend or API changes, live login, messages, purchases or clinical recommendations are implemented in this package.

Target: SQL Server 2019 or newer, including SQL Server Express, and Azure SQL Database. Runtime validation was performed on an isolated SQL Server 2025 LocalDB instance. SQL Server 2019 and Azure execution have not been tested directly.

## Run

Requires PowerShell and Microsoft `sqlcmd`. Use a new database for the first installation. The scripts never drop an existing database.

```powershell
# Local example; substitute your own SQL Server instance.
.\Install.ps1 -Server '.\SQLEXPRESS' -Database AarohiDemo -CreateDatabase -IncludeDemo -RunTests

# Reference data only; no fictional users, prescriptions or financial transactions.
.\Install.ps1 -Server '.\SQLEXPRESS' -Database Aarohi -CreateDatabase

# Azure SQL: create the database through your normal Azure process first.
.\Install.ps1 -Server 'tcp:YOUR-SERVER.database.windows.net,1433' -Database Aarohi -Entra
```

Windows integrated authentication is the default. SQL authentication is supported with `-SqlUser` and an externally set `SQLCMDPASSWORD`; no passwords are included or printed. Do not disable TLS certificate validation to work around a connection failure.

In SSMS, select your target database and run scripts in order. Use UTF-8 when opening files. `GO` separators are supported by SSMS and sqlcmd.

| File | Purpose |
|---|---|
| `001_schema.sql` | 76 application tables, relationships, constraints and indexes; plus a migration ledger |
| `002_reference_data.sql` | Configurable application/catalogue seed records |
| `003_demo_data.sql` | Optional fictional households and test transactions |
| `004_views_security.sql` | Query views, alert function, household RLS and database roles |
| `005_integrity.sql` | Dropdown-category checks, stock guards, menu cycle and prescription/retailer rules |
| `006_tests.sql` | Read assertions and rollback-based negative/permission tests; demo database only |
| `007_example_queries.sql` | Read-only navigation, photo, pantry, reminder and finance examples |
| `assets/` | Actual food JPEGs with checksums; matches media metadata |
| `SCHEMA_REFERENCE.md` | Complete table and column dictionary |
| `MODEL.md` | Entity relationship overview and application contracts |

**Latest update:** run the installer to apply migrations 008–011 for the current design. See [LATEST-DESIGN.md](LATEST-DESIGN.md) for language support, seven grocery/seven pharmacy providers, menu consolidation, pantry visual configuration and financial scenarios. Test 012 covers these changes; 013 contains example queries.

The schema/reference/demo migrations use version markers and transactions. Re-running them skips already-applied data; seed scripts never overwrite administrator edits. Views, grants and triggers are re-applied. Make future changes using new numbered migrations; editing an applied seed script will not update records.

## Configuration coverage

- Brand, themes, colors, feature flags, settings, translations, language choices.
- Menus and nested submenus, routes, icons, optional images, ordering, visibility, permission and feature bindings. Grocery and pharmacy sections are children of one shopping menu.
- Media storage provider/key, MIME type, file size, checksum, alternative text and AI-image label. Recipes reference media rows; images are not hard-coded in the application schema.
- All 28 states and 8 union territories, 79 cuisine preferences and state/style recipe mappings. Region `Code` is an internal application code, not an ISO subdivision code.
- Dropdown catalogues for diets, health document types, conditions, severity, medicine forms, metrics, meal types, reminder kinds and units.
- Google OIDC, SMS OTP and email OTP provider configuration; JWT issuer/audience, algorithm, token expiry, rotation requirement and signing-key reference.
- Notification templates/channels, per-user preferences, per-member reminder times and per-ingredient alert thresholds.
- Grocery and pharmacy providers, website URLs, optional logos, API capabilities and secret references. All fourteen providers (after migration 009) start in `WebsiteOnly` mode.
- Financial categories, monthly budgets, salary/passive income, accounts, expenses, EMIs, assets, valuations, chits, goals and contributions.

Configuration does not mean storing executable code in tables. System lifecycle states, permission semantics and validation rules remain application/database contracts. `cfg.[Option]` labels and entries are configurable within validated option groups. Hierarchical menus are capped at 32 levels. The existing HTML wireframe remains standalone and is **not yet connected to this database**.

## Images and health files

The package contains 28 food JPEGs and 31 recipe-to-photo mappings. Upload `assets/food/` to your static host or Azure Blob Storage and update `cfg.MediaAsset.StorageProvider/StorageKey` and `cfg.Setting` key `media.baseUrl`. Check the asset manifest when copying. This keeps pictures replaceable without schema changes or binary data in ordinary database rows.

The ten currently named regional recipe sets are illustrative. Other regions map to explicitly flagged sample recipes. Substyles share the state recipe set until reviewed regional catalogues are supplied. Pantry ingredient quantities are synthetic, incomplete fixtures, not nutritional or allergen-safe recipes.

Health files are separate from public images: `health.Document` stores private storage keys, file metadata, scan/review state and owner. The fictional prescription path has **no actual medical file**. Future storage access must use short-lived authorized URLs after record-level permission checks. Do not store permanent public medical URLs or SAS tokens here. No extraction is trusted until confirmed.

## Authentication contracts for the future API

“Gmail-based login” is modelled as **Google OpenID Connect**; optional email OTP is independent. Google identity is keyed by provider + issuer + case-sensitive subject, not email. Never auto-link accounts simply because email addresses match. Verify issuer, audience, nonce, PKCE and verified contact claims in the backend before linking an identity.

JWT signing/validation is an API responsibility. Store keys in Key Vault or an equivalent secret manager and place only the key reference in the database. Access JWTs are not persisted. Store cryptographic hashes of high-entropy refresh tokens, with parent lineage, single-child uniqueness, expiry, consumption and revocation. The backend must rotate refresh tokens atomically and revoke the session family when replay is detected; constraints alone do not implement rotation.

OTP values and destinations are represented by keyed HMACs with key-version metadata. The backend must enforce expiry, attempts, purpose, resend limits and per-destination/IP throttling, then consume a challenge atomically. Never store plaintext OTPs, raw JWTs, Google access/refresh tokens, passwords or service credentials. The fixture HMACs are dummy bytes, not valid secrets.

All authentication providers and the signing policy are disabled in seed data. Demo users are `Pending`, with reserved `example.invalid` addresses and no verified contacts. The session is expired/revoked and the OTP challenge is expired/consumed. There are no demo login credentials.

## Household security and consent

Household-scoped tables use composite keys and relationships containing `HouseholdId`. Documents, prescriptions and medicine items also enforce member ownership. RLS filters reads and blocks cross-household inserts/updates. No household session context means no household records, even for normal owner queries.

```sql
-- Only after the trusted backend verifies the authenticated user's active membership:
EXEC sys.sp_set_session_context @key=N'HouseholdId', @value=1;
SELECT * FROM family.Member;
-- Clear/replace on every checked-out pooled connection; never reuse another request's context.
EXEC sys.sp_set_session_context @key=N'HouseholdId', @value=NULL;
```

RLS is a tenant-isolation guard, **not proof of identity**: a caller who possesses SQL credentials can set session context. Only the trusted backend holds database credentials. Validate JWT, session revocation, household membership, role permission and member-level grants/consent before every sensitive operation. `family.MemberAccess` and `family.Consent` model those grants; the API must enforce them. Children have profiles and guardian references without needing login accounts. Financial role permissions and medical member permissions must be evaluated separately.

Database roles: `aarohi_app` for operational data, `aarohi_auth` for authentication material, and `aarohi_config_admin` for configuration/catalogue changes. No logins are created or assigned automatically. Map separate deployment/application identities deliberately. The application role cannot read OTP/token tables, change configuration or rewrite audit events. Audit payloads must not contain documents, codes, tokens or full medical/financial payloads. Database owners retain administrative control; this is not an immutable compliance archive.

## Data conventions

- UTC timestamps use `datetime2(3)`. Birth and expiry dates use `date`. Reminder local times use `time(0)` plus IANA zone, initially `Asia/Kolkata`. Weekday mask: Monday 1, Tuesday 2, Wednesday 4, Thursday 8, Friday 16, Saturday 32, Sunday 64; 127 is daily. The future scheduler must generate unique UTC occurrences with timezone handling.
- Age is calculated from DOB; `BirthDateIsEstimated` distinguishes approximate dates. Validate future DOB and guardian/member access changes in the API.
- `rowversion` supports optimistic concurrency; it is not a timestamp. Use it in update predicates and treat zero-row updates as conflicts.
- Pantry quantity is derived from movements per lot. Multiple expiries are supported. The database rejects negative stock and changes to a lot's unit/ingredient once movements exist. The backend must lock/retry deadlocks and convert compatible units; do not sum kilograms and grams directly. Current alert aggregation compares like units only.
- Money uses exact decimal values and an explicit household/account/quote currency. Transaction amounts are signed: positive inflow, negative outflow. Expense refunds are positive. Transfer pairs must be posted atomically and balance to zero. The API must enforce category compatibility and currency consistency.
- Budget and savings totals are calculated views. Asset valuation history is separate from acquisition cost. Avoid representing the same money twice as both an account balance and an asset valuation. Chit contributions are not automatically assets or guaranteed returns; linked liability records represent obligations.
- Quote comparisons include pack counts and delivery/other fees; expiry, complete coverage and actual availability must be checked before display. Quotes are snapshots, not promises. Fixture quotes are marked `IsDemo=1` and expire on 24 Oct 2026. `Unknown` inventory is never counted as available.
- Prescription purchases reference exact member/prescription items. No automatic medicine substitutions, prescribing, pharmacy cart transfer or checkout is implemented.
- No cascaded deletion of health or financial history. Plan retention, archival and deletion explicitly. SQL Server encryption, backup, secret rotation, monitoring and production authentication setup remain deployment work.

## Test data and validation

Two independent households, four pending login accounts, five family profiles (including a child), consent/grants, a fictional prescription, allergy/history/observation examples, four pantry lots, meal and medicine schedules, a cancelled notification fixture, grocery and medicine lists, three demo retailer quotes, a draft pharmacy order, salary/rental income, budgets, expenses, loans, mutual funds/stocks/property/deposit valuations, a chit record and a savings goal.

No SMS/email/push sender, scheduled worker or partner API is invoked by these scripts. Outbox fixture is cancelled. Run tests only in a disposable test database with demo data: assertions expect the untouched fixtures. Negative tests roll back; identity counters can still advance on rejected/rolled-back inserts, which is normal.

Validation output is in `validation-results.txt`. It covers photo/cuisine coverage, household read/write isolation, cross-household/member foreign keys, wrong option groups, invalid JSON, cyclic menus, stock guards, prescription-dependent reminders, provider categories, token uniqueness, notification deduplication, calculation results and actual database role permissions.

Sources for SQL Server mechanisms: [row-level security](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security?view=sql-server-ver17), [CREATE TABLE and constraints](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver17). Official pharmacy destinations are configured as website links, not claimed partner integrations.
