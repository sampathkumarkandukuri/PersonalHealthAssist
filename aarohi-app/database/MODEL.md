# Aarohi data model

```mermaid
erDiagram
  USER_ACCOUNT ||--o{ EXTERNAL_IDENTITY : authenticates
  USER_ACCOUNT ||--o{ SESSION : owns
  SESSION ||--o{ REFRESH_TOKEN : rotates
  USER_ACCOUNT ||--o{ MEMBERSHIP : joins
  HOUSEHOLD ||--o{ MEMBERSHIP : grants
  ROLE ||--o{ MEMBERSHIP : assigns
  HOUSEHOLD ||--o{ MEMBER : includes
  MEMBER ||--o{ DOCUMENT : owns
  DOCUMENT ||--o{ PRESCRIPTION : supports
  PRESCRIPTION ||--o{ PRESCRIPTION_ITEM : contains
  MEMBER ||--o{ REMINDER : schedules
  REMINDER ||--o{ REMINDER_TIME : repeats
  REMINDER_TIME ||--o{ OCCURRENCE : generates
  HOUSEHOLD ||--o{ STOCK_LOT : stores
  STOCK_LOT ||--o{ MOVEMENT : balances
  INGREDIENT ||--o{ STOCK_LOT : identifies
  RECIPE ||--o{ RECIPE_INGREDIENT : requires
  INGREDIENT ||--o{ RECIPE_INGREDIENT : supplies
  MEDIA_ASSET ||--o{ RECIPE : illustrates
  REGION ||--o{ CUISINE : offers
  CUISINE ||--o{ RECIPE_CUISINE : maps
  RECIPE ||--o{ RECIPE_CUISINE : maps
  HOUSEHOLD ||--o{ SHOPPING_LIST : owns
  SHOPPING_LIST ||--o{ SHOPPING_ITEM : contains
  SHOPPING_LIST ||--o{ QUOTE : compares
  PROVIDER ||--o{ QUOTE : quotes
  QUOTE ||--o{ QUOTE_ITEM : prices
  HOUSEHOLD ||--o{ ACCOUNT : owns
  ACCOUNT ||--o{ TRANSACTION_RECORD : records
  HOUSEHOLD ||--o{ BUDGET : allocates
  HOUSEHOLD ||--o{ LIABILITY : owes
  HOUSEHOLD ||--o{ ASSET : owns
  ASSET ||--o{ ASSET_VALUATION : values
  HOUSEHOLD ||--o{ SAVINGS_GOAL : plans
  SAVINGS_GOAL ||--o{ GOAL_CONTRIBUTION : funds
  MENU ||--o{ MENU : contains
```

The diagram is an overview. SQL composite foreign keys, especially household and member ownership, are the authoritative relationships; see `SCHEMA_REFERENCE.md`.

| Area | Key design |
|---|---|
| Configuration | Typed core tables; JSON only for flexible theme/provider/settings payloads, not primary relationships |
| Pictures | Reusable media metadata with real packaged image files; private health documents use a separate model |
| Authentication | Google subject/issuer identities, keyed OTP checks, revocable sessions and hashed refresh lineage |
| Family | Login account differs from family member; one user can belong to multiple households |
| Health | Document ownership and prescription items constrained to the correct member; draft extraction is separate |
| Food | Recipe-to-cuisine mapping supports different styles without duplicate recipe/photo records |
| Pantry | Lot-based expiry and movement-based stock; alert rules per ingredient/unit |
| Reminders | Schedules differ from occurrences, completion and delivery attempts |
| Shopping | One list model with strict grocery/medicine branches; quotes/orders preserve provenance |
| Finance | Plans differ from posted transactions; valuation history and savings contributions remain auditable |

Required API transactions, not implemented in this DB-only phase: account-link verification; OTP consumption and attempt locking; refresh rotation/replay revocation; last-admin protection; membership/consent enforcement; balanced account transfers; scheduler occurrence/outbox creation and retry leases; pharmacy review/checkout; external-provider synchronization. These require authenticated requests or workers and cannot be supplied by seed data.


Latest design adds nine tenant-scoped tables and six configuration/catalogue tables (91 application tables total). See LATEST-DESIGN.md and migration 008 for the scenario aggregate and language/media/comparison additions.
