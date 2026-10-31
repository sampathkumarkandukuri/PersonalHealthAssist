SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
CREATE OR ALTER VIEW pantry.vLotBalance AS
 SELECT l.HouseholdId,l.Id AS StockLotId,l.IngredientId,l.UnitId,l.LotCode,l.ExpiresOn,
 COALESCE(SUM(m.QuantityDelta),CONVERT(decimal(38,4),0)) AS Quantity
 FROM pantry.StockLot l LEFT JOIN pantry.Movement m ON m.HouseholdId=l.HouseholdId AND m.StockLotId=l.Id
 GROUP BY l.HouseholdId,l.Id,l.IngredientId,l.UnitId,l.LotCode,l.ExpiresOn;
GO
CREATE OR ALTER FUNCTION pantry.fnAlerts(@AsOfDate date)
RETURNS TABLE AS RETURN
 SELECT r.HouseholdId,r.Id AS RuleId,r.IngredientId,i.Name,r.UnitId,
 COALESCE(s.Quantity,0) AS Quantity,
 CONVERT(bit,CASE WHEN COALESCE(s.Quantity,0)<=r.LowStockQuantity THEN 1 ELSE 0 END) AS IsLowStock,
 CONVERT(decimal(18,2),COALESCE(s.Quantity,0)/NULLIF(r.DailyUsageQuantity,0)) AS EstimatedDaysRemaining,
 CONVERT(bit,CASE WHEN r.DailyUsageQuantity IS NOT NULL AND COALESCE(s.Quantity,0)/r.DailyUsageQuantity<=r.RunOutLeadDays THEN 1 ELSE 0 END) AS IsRunOutSoon,
 e.NextExpiry,
 CONVERT(bit,CASE WHEN e.NextExpiry<=DATEADD(day,r.ExpiryLeadDays,@AsOfDate) THEN 1 ELSE 0 END) AS IsExpiryWarning
 FROM pantry.AlertRule r JOIN food.Ingredient i ON i.Id=r.IngredientId
 OUTER APPLY (SELECT SUM(b.Quantity) Quantity FROM pantry.vLotBalance b WHERE b.HouseholdId=r.HouseholdId AND b.IngredientId=r.IngredientId AND b.UnitId=r.UnitId) s
 OUTER APPLY (SELECT MIN(b.ExpiresOn) NextExpiry FROM pantry.vLotBalance b WHERE b.HouseholdId=r.HouseholdId AND b.IngredientId=r.IngredientId AND b.UnitId=r.UnitId AND b.Quantity>0) e
 WHERE r.IsEnabled=1;
GO
CREATE OR ALTER VIEW finance.vBudgetActual AS
 SELECT b.HouseholdId,b.Id AS BudgetId,b.MonthStart,b.CategoryId,b.Amount AS Planned,
 COALESCE(-SUM(t.Amount),0) AS Spent,
 b.Amount+COALESCE(SUM(t.Amount),0) AS Remaining
 FROM finance.Budget b LEFT JOIN finance.TransactionRecord t
 ON t.HouseholdId=b.HouseholdId AND t.CategoryId=b.CategoryId AND t.Status='Posted'
 AND t.OccurredOn>=b.MonthStart AND t.OccurredOn<DATEADD(month,1,b.MonthStart)
 GROUP BY b.HouseholdId,b.Id,b.MonthStart,b.CategoryId,b.Amount;
GO
CREATE OR ALTER VIEW finance.vGoalProgress AS
 SELECT g.HouseholdId,g.Id AS GoalId,g.Name,g.TargetAmount,g.MonthlyAllocation,
 g.OpeningSavedAmount+COALESCE(SUM(c.Amount),0) AS SavedAmount
 FROM finance.SavingsGoal g LEFT JOIN finance.GoalContribution c ON c.HouseholdId=g.HouseholdId AND c.GoalId=g.Id
 GROUP BY g.HouseholdId,g.Id,g.Name,g.TargetAmount,g.MonthlyAllocation,g.OpeningSavedAmount;
GO
CREATE OR ALTER VIEW commerce.vQuoteTotal AS
 SELECT q.HouseholdId,q.Id AS QuoteId,q.ShoppingListId,q.ProviderId,q.CurrencyCode,q.QuotedAtUtc,q.ExpiresAtUtc,q.IsDemo,
 SUM(CONVERT(decimal(18,2),i.PackPrice*i.PacksRequired)) AS ItemTotal,
 SUM(CONVERT(decimal(18,2),i.PackPrice*i.PacksRequired))+q.DeliveryFee+q.OtherFees-q.BasketDiscount AS Total,
 CONVERT(bit,CASE WHEN COUNT(i.Id)=(SELECT COUNT(*) FROM commerce.ShoppingItem s WHERE s.HouseholdId=q.HouseholdId AND s.ShoppingListId=q.ShoppingListId)
 AND COUNT(i.Id)>0 AND MIN(CASE WHEN i.Availability='Available' THEN 1 ELSE 0 END)=1 THEN 1 ELSE 0 END) AS IsCompleteAndAvailable
 FROM commerce.Quote q LEFT JOIN commerce.QuoteItem i ON i.HouseholdId=q.HouseholdId AND i.QuoteId=q.Id
 GROUP BY q.HouseholdId,q.Id,q.ShoppingListId,q.ProviderId,q.CurrencyCode,q.QuotedAtUtc,q.ExpiresAtUtc,q.IsDemo,q.DeliveryFee,q.OtherFees,q.BasketDiscount;
GO
CREATE OR ALTER VIEW cfg.vPublicSettings AS SELECT Code,ValueJson FROM cfg.Setting WHERE IsPublic=1;
GO
-- The trusted API must validate household membership before setting this context.
-- SQL credentials are NEVER issued to browser/mobile users. No context => no household rows.
-- A bound security predicate cannot be ALTERed while its policy references it.
-- Create once; future predicate changes require an explicit security migration.
IF OBJECT_ID(N'auth.fnHouseholdAccess',N'IF') IS NULL
 EXEC(N'CREATE FUNCTION auth.fnHouseholdAccess(@HouseholdId bigint)
 RETURNS TABLE WITH SCHEMABINDING AS RETURN
 SELECT 1 AS Allowed WHERE @HouseholdId=TRY_CONVERT(bigint,SESSION_CONTEXT(N''HouseholdId''));');
GO
BEGIN TRANSACTION;
IF DATABASE_PRINCIPAL_ID(N'aarohi_app') IS NULL CREATE ROLE aarohi_app AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'aarohi_auth') IS NULL CREATE ROLE aarohi_auth AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'aarohi_config_admin') IS NULL CREATE ROLE aarohi_config_admin AUTHORIZATION dbo;
IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name='HouseholdIsolation' AND schema_id=SCHEMA_ID('auth'))
BEGIN
 DECLARE @sql nvarchar(max)=N'CREATE SECURITY POLICY auth.HouseholdIsolation ';
 SELECT @sql+=N'ADD FILTER PREDICATE auth.fnHouseholdAccess('+QUOTENAME(c.name)+N') ON '+QUOTENAME(s.name)+N'.'+QUOTENAME(t.name)+N', '+
 N'ADD BLOCK PREDICATE auth.fnHouseholdAccess('+QUOTENAME(c.name)+N') ON '+QUOTENAME(s.name)+N'.'+QUOTENAME(t.name)+N' AFTER INSERT, '+
 N'ADD BLOCK PREDICATE auth.fnHouseholdAccess('+QUOTENAME(c.name)+N') ON '+QUOTENAME(s.name)+N'.'+QUOTENAME(t.name)+N' AFTER UPDATE, '
 FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.columns c ON c.object_id=t.object_id
 WHERE c.name='HouseholdId' OR (s.name='family' AND t.name='Household' AND c.name='Id');
 SET @sql=LEFT(@sql,LEN(@sql)-1); -- remove trailing comma (LEN ignores trailing space)
 SET @sql+=N' WITH (STATE=ON, SCHEMABINDING=ON);';
 EXEC sys.sp_executesql @sql;
END;
-- Trusted application tier: operational data, not auth material or configuration writes.
GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA::family TO aarohi_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA::health TO aarohi_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA::pantry TO aarohi_app;
GRANT SELECT ON SCHEMA::food TO aarohi_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON food.MealPlan TO aarohi_app;
GRANT SELECT ON SCHEMA::cfg TO aarohi_app;
DENY SELECT ON cfg.Setting TO aarohi_app;
GRANT SELECT ON cfg.vPublicSettings TO aarohi_app;
GRANT SELECT ON auth.Role TO aarohi_app;
GRANT SELECT ON auth.Permission TO aarohi_app;
GRANT SELECT ON auth.RolePermission TO aarohi_app;
GRANT SELECT,INSERT ON audit.Event TO aarohi_app;
DENY UPDATE,DELETE ON audit.Event TO aarohi_app;
DECLARE @grant nvarchar(max)=N'';
SELECT @grant+=N'GRANT SELECT,INSERT,UPDATE,DELETE ON '+QUOTENAME(s.name)+N'.'+QUOTENAME(t.name)+N' TO aarohi_app;'
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
WHERE s.name IN ('finance','notify','commerce') AND EXISTS(SELECT 1 FROM sys.columns c WHERE c.object_id=t.object_id AND c.name='HouseholdId');
EXEC sys.sp_executesql @grant;
GRANT SELECT ON finance.Category TO aarohi_app;
GRANT SELECT ON finance.vBudgetActual TO aarohi_app;
GRANT SELECT ON finance.vGoalProgress TO aarohi_app;
GRANT SELECT ON commerce.Provider TO aarohi_app;
GRANT SELECT ON commerce.vQuoteTotal TO aarohi_app;
GRANT SELECT ON notify.Channel TO aarohi_app;
GRANT SELECT ON notify.Template TO aarohi_app;
-- Auth service privileges separated from the household application role.
GRANT SELECT,INSERT,UPDATE ON auth.UserAccount TO aarohi_auth;
GRANT SELECT,INSERT,UPDATE,DELETE ON auth.ExternalIdentity TO aarohi_auth;
GRANT SELECT,INSERT,UPDATE,DELETE ON auth.AuthChallenge TO aarohi_auth;
GRANT SELECT,INSERT,UPDATE,DELETE ON auth.Session TO aarohi_auth;
GRANT SELECT,INSERT,UPDATE,DELETE ON auth.RefreshToken TO aarohi_auth;
GRANT SELECT,INSERT,DELETE ON auth.RevokedAccessToken TO aarohi_auth;
GRANT SELECT ON auth.Provider TO aarohi_auth;
GRANT SELECT ON auth.TokenPolicy TO aarohi_auth;
GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA::cfg TO aarohi_config_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON food.Recipe TO aarohi_config_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON food.RecipeCuisine TO aarohi_config_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON food.RecipeIngredient TO aarohi_config_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON commerce.Provider TO aarohi_config_admin;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='004') INSERT dbo.SchemaMigration(Version) VALUES('004');
COMMIT;
GO
