SET NOCOUNT ON; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO
CREATE OR ALTER VIEW finance.vPlanOverview AS
SELECT s.HouseholdId,s.Id AS ScenarioId,s.Name,s.CurrencyCode,s.AsOfDate,s.CalculationVersion,
 a.Assets,d.Debts,a.Assets-d.Debts AS NetWorth,f.Income,f.Essential,f.Lifestyle,f.CurrentInvestments,f.AnnualReserve/12 AS MonthlyAnnualReserve,
 d.Emi,p.AnnualPremium/12 AS MonthlyPremium,
 f.Income-f.Essential-f.Lifestyle-f.AnnualReserve/12-d.Emi-p.AnnualPremium/12 AS CapacityBeforeInvestments,
 f.Income-f.Essential-f.Lifestyle-f.AnnualReserve/12-d.Emi-p.AnnualPremium/12-f.CurrentInvestments AS UnallocatedCash,
 (f.Essential+d.Emi+p.AnnualPremium/12)*s.EmergencyMonths AS EmergencyTarget
FROM finance.PlanScenario s
OUTER APPLY(SELECT COALESCE(SUM(CurrentValue),0) Assets FROM finance.PlanAsset WHERE HouseholdId=s.HouseholdId AND ScenarioId=s.Id)a
OUTER APPLY(SELECT COALESCE(SUM(OutstandingBalance),0) Debts,COALESCE(SUM(MonthlyEmi),0) Emi FROM finance.PlanDebt WHERE HouseholdId=s.HouseholdId AND ScenarioId=s.Id)d
OUTER APPLY(SELECT COALESCE(SUM(AnnualPremium),0) AnnualPremium FROM finance.PlanPolicy WHERE HouseholdId=s.HouseholdId AND ScenarioId=s.Id)p
OUTER APPLY(SELECT COALESCE(SUM(CASE WHEN Kind='Income' THEN Amount END),0) Income,COALESCE(SUM(CASE WHEN Kind='Essential' THEN Amount END),0) Essential,COALESCE(SUM(CASE WHEN Kind='Lifestyle' THEN Amount END),0) Lifestyle,COALESCE(SUM(CASE WHEN Kind='Investment' THEN Amount END),0) CurrentInvestments,COALESCE(SUM(CASE WHEN Kind='AnnualReserve' THEN Amount END),0) AnnualReserve FROM finance.PlanFlow WHERE HouseholdId=s.HouseholdId AND ScenarioId=s.Id)f;
GO
CREATE OR ALTER VIEW commerce.vComparisonSummary AS
SELECT t.HouseholdId,t.QuoteId,t.ShoppingListId,t.ProviderId,t.CurrencyCode,t.IsDemo,t.ItemTotal,
 CASE WHEN v.FeesKnown=1 THEN t.Total END AS KnownDeliveredTotal,
 CONVERT(bit,CASE WHEN t.IsCompleteAndAvailable=1 AND v.ExactBasketMatchVerified=1 AND v.FeesKnown=1 AND t.ExpiresAtUtc>SYSUTCDATETIME() AND t.QuotedAtUtc<=SYSUTCDATETIME() AND t.IsDemo=0 AND t.Total>=0 THEN 1 ELSE 0 END) AS IsEligibleForLiveRanking
FROM commerce.vQuoteTotal t LEFT JOIN commerce.QuoteVerification v ON v.HouseholdId=t.HouseholdId AND v.QuoteId=t.QuoteId;
GO
CREATE OR ALTER FUNCTION cfg.fnInterfaceText(@LanguageCode varchar(12)) RETURNS TABLE AS RETURN
SELECT r.ResourceKey,r.SourceText,COALESCE(t.Text,en.Text,r.SourceText) AS DisplayText
FROM cfg.TextResource r
LEFT JOIN cfg.Language l ON l.Code=@LanguageCode AND l.IsActive=1
LEFT JOIN cfg.Translation t ON t.LanguageId=l.Id AND t.ResourceKey=r.ResourceKey
LEFT JOIN cfg.Language e ON e.Code='en-IN'
LEFT JOIN cfg.Translation en ON en.LanguageId=e.Id AND en.ResourceKey=r.ResourceKey;
GO
GRANT SELECT ON finance.vPlanOverview TO aarohi_app;
GRANT SELECT ON commerce.vComparisonSummary TO aarohi_app;
GRANT SELECT ON cfg.fnInterfaceText TO aarohi_app;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='011') INSERT dbo.SchemaMigration(Version) VALUES('011');
