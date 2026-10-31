SET NOCOUNT ON; SET XACT_ABORT ON; SET QUOTED_IDENTIFIER ON;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='010') BEGIN PRINT '010 already applied'; RETURN; END;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='003') THROW 52100,'Original demo fixtures required.',1;
BEGIN TRY BEGIN TRANSACTION;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=1;
INSERT family.InterfacePreference(HouseholdId,UserId,LanguageId,ThemeId) SELECT 1,1,Id,1 FROM cfg.Language WHERE Code='ar';
INSERT family.InterfacePreference(HouseholdId,UserId,LanguageId,ThemeId) SELECT 1,2,Id,1 FROM cfg.Language WHERE Code='es';
INSERT finance.PlanScenario(HouseholdId,Name,AsOfDate,RetireSaved,RetireContribution,EmergencySaved,EmergencyContribution,HealthCoverTarget)
VALUES(1,N'Fictional family plan — October 2026','20261025',1000000,15000,200000,5000,1000000);
DECLARE @Plan bigint=SCOPE_IDENTITY();
INSERT finance.PlanPerson(HouseholdId,ScenarioId,Name,DateOfBirth,RetirementAge,IsRetirementPerson) VALUES(1,@Plan,N'Ananya Demo','19900101',60,1);
INSERT finance.PlanPerson(HouseholdId,ScenarioId,Name,DateOfBirth,RetirementAge) VALUES(1,@Plan,N'Child Demo','20160101',60);
DECLARE @Child bigint=SCOPE_IDENTITY();
INSERT finance.PlanAsset(HouseholdId,ScenarioId,Name,AssetType,CurrentValue) VALUES(1,@Plan,N'Family home','Property',6000000),(1,@Plan,N'Investments','Mutual funds',1200000),(1,@Plan,N'Cash','Bank / cash',300000);
INSERT finance.PlanDebt(HouseholdId,ScenarioId,Name,OutstandingBalance,MonthlyEmi,InterestPercent,RemainingMonths) VALUES(1,@Plan,N'Home loan',2000000,22000,8.5,180);
INSERT finance.PlanFlow(HouseholdId,ScenarioId,Name,Kind,Amount) VALUES(1,@Plan,N'Take-home salary','Income',150000),(1,@Plan,N'Essential costs','Essential',30000),(1,@Plan,N'Lifestyle','Lifestyle',12000),(1,@Plan,N'Current investments','Investment',20000),(1,@Plan,N'Annual expenses','AnnualReserve',60000);
INSERT finance.PlanPolicy(HouseholdId,ScenarioId,Name,Kind,CoverAmount,AnnualPremium) VALUES(1,@Plan,N'Life cover','Life',5000000,24000),(1,@Plan,N'Health cover','Health',500000,18000);
INSERT finance.PlanGoal(HouseholdId,ScenarioId,PersonId,Name,CurrentCost,EarmarkedSavings,TargetBasis,TargetAge) VALUES(1,@Plan,@Child,N'Education at age 18',1200000,100000,'Age',18);
INSERT finance.PlanGoal(HouseholdId,ScenarioId,Name,CurrentCost,EarmarkedSavings,TargetBasis,TargetDate) VALUES(1,@Plan,N'Family holiday',120000,45000,'Date','20271025');
INSERT commerce.DemoProduct(Code,Name,PackDescription,Category) VALUES('rice',N'Sona masoori rice',N'1 kg',N'Staples'),('dal',N'Toor dal',N'1 kg',N'Staples'),('milk',N'Toned milk',N'500 ml',N'Dairy'),('tomato',N'Tomatoes',N'500 g',N'Vegetables'),('oil',N'Groundnut oil',N'1 litre',N'Staples'),('oats',N'Rolled oats',N'500 g',N'Staples');
INSERT commerce.DemoOffer(ProductId,ProviderId,PackPrice)
SELECT d.Id,p.Id,CASE p.Code WHEN 'blinkit' THEN x.B WHEN 'zepto' THEN x.Z WHEN 'bigbasket' THEN x.BB END
FROM (VALUES('rice',72,75,69),('dal',165,159,162),('milk',29,30,29),('tomato',28,25,NULL),('oil',189,195,185),('oats',95,99,92))x(Code,B,Z,BB)
JOIN commerce.DemoProduct d ON d.Code=x.Code CROSS JOIN commerce.Provider p WHERE p.Category='Grocery';
INSERT dbo.SchemaMigration(Version) VALUES('010'); COMMIT;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=NULL;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=NULL; THROW; END CATCH;
