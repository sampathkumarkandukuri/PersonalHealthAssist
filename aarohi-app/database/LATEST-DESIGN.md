# Latest design migration — October 2026

Apply using Install.ps1. Original migrations 001–005 are unchanged. New migrations 008–011 run after the original security and integrity scripts. Migration 010 is optional with -IncludeDemo. Tests 006 and 012 run with -RunTests. Script 013 is read-only usage examples and is not run by the installer.

## Added configuration and data

- Seven grocery platforms and seven pharmacies. All are website-only, with live-price lookup and cart transfer disabled. Provider Code is unique. Pharmacy coverage must be checked by PIN code with the provider; no delivery-time promises are seeded.
- Hidden standalone wealth and goals menus, retained records, and legacy route aliases into the financial planner. Three child menus under Money & budget. Nine configurable planner steps in cfg.Setting.
- English (en-IN), Spanish (es) and Arabic (ar) interface choices. Arabic direction is rtl. Other existing regional languages remain in the language catalogue, but are not advertised as supported interface translations.
- 472 source resources and 1,416 translated rows. ui-resource-map.json maps exact wireframe source labels to stable hash-based keys. cfg.fnInterfaceText provides an English fallback. This imports the wireframe's partial translation coverage; it does not claim all detailed prose or expense parsing is multilingual.
- Per-household, per-user interface preferences, linked to active membership records by foreign key. The backend must verify active membership and that the requested language/theme is enabled. Language changes do not convert currency or translate medical/user-entered content.
- Pantry category, accent color and ordering per ingredient. Existing food.Ingredient.MediaId remains the image reference. The interrupted image redesign did not yield verified delivered assets: ImageState is Pending and no nonexistent image files or paths are seeded. Attach verified public assets through cfg.MediaAsset and then set ImageState to Ready.
- No night-mode capability is advertised. The existing light theme is retained.
- Six fictional generic grocery products, with 42 provider-offer rows in the optional demo. Missing quotes are NULL, including every quote for the four newly added grocery platforms. These global demonstration tables are separate from tenant quote/order records; they cannot be used as live price evidence. No medicine prices or substitute medicines are seeded.

## Financial planner storage

finance.PlanScenario stores dated, currency-specific assumptions and retirement/emergency/protection input allocations. PlanPerson, PlanAsset, PlanDebt, PlanFlow, PlanPolicy and PlanGoal store scenario inputs. These are snapshots for planning, separate from recorded transactions and savings contributions. Editing a scenario does not post an expense or change an account balance.

Only one retirement person is allowed per scenario. Goals support either a target date or a person's target age, with a composite foreign key ensuring the person belongs to that scenario and household. Children's goals use the same goal table, not duplicate balances. Amounts are nonnegative. Percentage assumptions must exceed -100%. The API must validate retirement age against DOB/as-of date and end age, prevent overlapping allocations, flag infeasible dates, and apply currency precision before saving/calculating.

PlanFlow.Kind=AnnualReserve is entered per year; other cash flows are monthly. Debt EMIs and policy premiums are included exactly once by finance.vPlanOverview. Its fictional scenario has assets 7,500,000, debts 2,000,000, capacity before investments 77,500 and unallocated monthly cash 57,500 INR.

Retirement projections, goal SIP math and protection formulas remain application calculations. CalculationVersion records the algorithm contract; SQL does not claim to execute these projections. See the wireframe FINANCIAL-PLAN.md for the current math. This package does not add automatic bank access, parse natural-language expenses, or connect the HTML to SQL Server. Existing finance.TransactionRecord, Budget, SavingsGoal and GoalContribution remain the recorded-finance model; production refund linking and parser review must be enforced by the API before posting ledger records.

## Safer comparison semantics

commerce.QuoteVerification defaults both fee knowledge and exact basket matching to false. commerce.vComparisonSummary returns no delivered total when fees are unknown, and only permits live ranking when the quote is complete, available, current, not a demo, exact-match verified, fees known, and nonnegative. An absent quote is not zero-cost. The original vQuoteTotal is a raw calculation view, not a live ranking recommendation. API implementations must use the new eligibility flag, compare the same shopping list/currency/location, and verify individual medicine brand/strength/form/pack before marking a match.

## Security and migration behavior

All nine new household tables have read filters and after-insert/update block predicates using the existing household isolation function. Schema migration, predicates and grants are transactional. Composite foreign keys prevent cross-household references. Config and global example offers are read-only to the application role. InterfacePreference is household-scoped; within-household self/admin access remains an API authorization responsibility.

Migrations run once via dbo.SchemaMigration. Reference inserts do not reapply on rerun; configuration changes survive repeated installs. The requested hiding of wealth/goals is an explicit one-time navigation change. Use new migrations for future edits; do not regenerate already-applied migrations with the original build helpers. No database or user data is dropped.

The installer supports existing deployments, fresh installs and reference-only installs followed later by optional demo fixtures. Validate on a disposable database before deployment to a real environment. SQL Server 2019+/Azure SQL syntax is targeted; runtime verification uses SQL Server 2025 LocalDB only.

## Verified results

Passed on isolated LocalDB databases: upgrade from the original schema, repeat installation, fresh reference-only installation, optional demo installation afterward, original integrity tests, and new language/platform/plan/RLS/permission tests. See latest-validation-results.txt. No existing business database was modified.
