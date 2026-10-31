-- Run only with 003_demo_data.sql in a disposable/test database; writes are rolled back.
SET NOCOUNT ON; SET XACT_ABORT OFF; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='003') THROW 52000,'Demo fixtures are required for this test suite.',1;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=NULL;
IF EXISTS(SELECT 1 FROM family.Member) THROW 52000,'FAIL: missing tenant context leaked family records.',1;
IF EXISTS(SELECT 1 FROM family.Household) THROW 52000,'FAIL: missing tenant context leaked households.',1;
IF (SELECT COUNT(*) FROM cfg.Region WHERE RegionType='State')<>28 THROW 52000,'FAIL: expected 28 states.',1;
IF (SELECT COUNT(*) FROM cfg.Region WHERE RegionType='UnionTerritory')<>8 THROW 52000,'FAIL: expected 8 union territories.',1;
IF EXISTS(SELECT 1 FROM cfg.Cuisine c WHERE NOT EXISTS(SELECT 1 FROM food.RecipeCuisine r WHERE r.CuisineId=c.Id)) THROW 52000,'FAIL: cuisine has no recipe mappings.',1;
IF EXISTS(SELECT 1 FROM food.Recipe r LEFT JOIN cfg.MediaAsset m ON m.Id=r.MediaId WHERE m.Id IS NULL OR m.IsActive=0) THROW 52000,'FAIL: missing recipe photo.',1;
IF (SELECT COUNT(*) FROM cfg.Menu WHERE Code='shop')<>1 OR (SELECT COUNT(*) FROM cfg.Menu c JOIN cfg.Menu p ON p.Id=c.ParentId WHERE p.Code='shop')<>2 THROW 52000,'FAIL: shopping navigation is not consolidated.',1;
IF EXISTS(SELECT 1 FROM auth.Provider WHERE IsEnabled=1) OR EXISTS(SELECT 1 FROM auth.TokenPolicy WHERE IsEnabled=1) THROW 52000,'FAIL: fixture authentication must be disabled.',1;
IF EXISTS(SELECT 1 FROM commerce.Provider WHERE SupportsCartTransfer=1 OR SupportsPriceLookup=1) THROW 52000,'FAIL: fixtures must not claim live retailer APIs.',1;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=1;
IF (SELECT COUNT(*) FROM family.Member)<>4 THROW 52000,'FAIL: household 1 member isolation.',1;
IF EXISTS(SELECT 1 FROM family.Member WHERE HouseholdId=2) THROW 52000,'FAIL: household 2 data leaked.',1;
IF (SELECT Quantity FROM pantry.vLotBalance WHERE StockLotId=1)<>5 THROW 52000,'FAIL: stock balance calculation.',1;
IF NOT EXISTS(SELECT 1 FROM pantry.fnAlerts('2026-10-24') WHERE Name='Spinach' AND IsLowStock=1 AND IsRunOutSoon=1 AND IsExpiryWarning=1) THROW 52000,'FAIL: grocery alerts.',1;
IF (SELECT Spent FROM finance.vBudgetActual WHERE CategoryId=(SELECT Id FROM finance.Category WHERE Code='groceries'))<>8400 THROW 52000,'FAIL: budget actual.',1;
IF (SELECT Remaining FROM finance.vBudgetActual WHERE CategoryId=(SELECT Id FROM finance.Category WHERE Code='groceries'))<>3600 THROW 52000,'FAIL: budget remaining.',1;
IF (SELECT SavedAmount FROM finance.vGoalProgress WHERE GoalId=1)<>245000 THROW 52000,'FAIL: savings total.',1;
IF (SELECT Total FROM commerce.vQuoteTotal WHERE QuoteId=1)<>170 THROW 52000,'FAIL: basket fees and pack math.',1;
IF EXISTS(SELECT 1 FROM commerce.vQuoteTotal WHERE IsCompleteAndAvailable=1) THROW 52000,'FAIL: unknown stock cannot imply availability.',1;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=2;
IF (SELECT COUNT(*) FROM family.Member)<>1 OR EXISTS(SELECT 1 FROM health.Document) THROW 52000,'FAIL: household 2 isolation.',1;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=1;
PRINT 'PASS: reference coverage, photo links, tenant read isolation, disabled integrations and computed totals.';
GO
CREATE PROCEDURE #ExpectFailure @Sql nvarchar(max),@Expected int,@Label nvarchar(200)
AS BEGIN
 SET NOCOUNT ON;
 DECLARE @Actual int=0;
 BEGIN TRY BEGIN TRANSACTION; EXEC sys.sp_executesql @Sql; ROLLBACK; END TRY
 BEGIN CATCH SET @Actual=ERROR_NUMBER(); IF @@TRANCOUNT>0 ROLLBACK; END CATCH;
 IF @Actual<>@Expected BEGIN DECLARE @Message nvarchar(2048)=CONCAT('FAIL: ',@Label,' expected ',@Expected,' received ',@Actual); THROW 52001,@Message,1; END;
 PRINT CONCAT('PASS: ',@Label);
END;
GO
EXEC #ExpectFailure N'INSERT family.Member(HouseholdId,Name,Relationship) VALUES(2,N''Cross-tenant write'',N''Self'');',33504,N'RLS blocks foreign-household writes';
EXEC #ExpectFailure N'INSERT health.Observation(HouseholdId,MemberId,MetricOptionId,ObservedAt,NumericValue,RecordedByUserId) SELECT 1,5,o.Id,SYSUTCDATETIME(),7,1 FROM cfg.[Option] o JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code=''Metric'' AND o.Code=''sleep'';',547,N'Composite foreign key blocks cross-household member references';
EXEC #ExpectFailure N'UPDATE health.Prescription SET MemberId=3 WHERE HouseholdId=1 AND Id=1;',547,N'Prescription cannot use another member document';
EXEC #ExpectFailure N'UPDATE commerce.QuoteItem SET ShoppingListId=2 WHERE HouseholdId=1 AND Id=1;',547,N'Quote item cannot reference a different shopping list';
EXEC #ExpectFailure N'UPDATE finance.Budget SET Amount=-1 WHERE HouseholdId=1 AND Id=1;',547,N'Negative budget rejected';
EXEC #ExpectFailure N'UPDATE cfg.Theme SET TokensJson=N''bad json'' WHERE Id=1;',547,N'Invalid configuration JSON rejected';
EXEC #ExpectFailure N'UPDATE family.Member SET DietOptionId=(SELECT Id FROM cfg.[Option] WHERE Code=''tablet'') WHERE HouseholdId=1 AND Id=1;',51001,N'Wrong dropdown option group rejected';
EXEC #ExpectFailure N'UPDATE cfg.Menu SET ParentId=(SELECT Id FROM cfg.Menu WHERE Code=''shop.groceries'') WHERE Code=''shop'';',51003,N'Cyclic submenu rejected';
EXEC #ExpectFailure N'INSERT pantry.Movement(HouseholdId,StockLotId,QuantityDelta,ReasonOptionId,OccurredAt,IdempotencyKey,RecordedByUserId) SELECT 1,1,-100,Id,SYSUTCDATETIME(),NEWID(),1 FROM cfg.[Option] WHERE Code=''consumption'';',51004,N'Over-consumption cannot make stock negative';
EXEC #ExpectFailure N'UPDATE pantry.StockLot SET UnitId=2 WHERE HouseholdId=1 AND Id=1;',51005,N'Lot unit cannot change under existing movements';
EXEC #ExpectFailure N'UPDATE notify.Reminder SET PrescriptionItemId=NULL WHERE HouseholdId=1 AND Id=2;',51006,N'Medicine reminder requires prescription item';
EXEC #ExpectFailure N'UPDATE commerce.OrderRecord SET ProviderId=1 WHERE HouseholdId=1 AND Id=1;',51007,N'Medicine order cannot use grocery retailer';
EXEC #ExpectFailure N'UPDATE notify.ReminderTime SET WeekdayMask=0 WHERE HouseholdId=1 AND Id=1;',547,N'Empty weekday schedule rejected';
EXEC #ExpectFailure N'UPDATE notify.Occurrence SET Status=''Completed'' WHERE HouseholdId=1 AND Id=1;',547,N'Completion requires actual completion timestamp';
EXEC #ExpectFailure N'UPDATE auth.AuthChallenge SET AttemptCount=6 WHERE Id=1;',547,N'OTP attempt limit enforced';
EXEC #ExpectFailure N'INSERT auth.RefreshToken(SessionId,TokenHash,ExpiresAt) SELECT SessionId,TokenHash,DATEADD(day,1,SYSUTCDATETIME()) FROM auth.RefreshToken WHERE Id=1;',2627,N'Duplicate refresh-token hash rejected';
EXEC #ExpectFailure N'INSERT notify.Outbox(HouseholdId,RecipientUserId,TemplateId,DedupeKey,PayloadJson,ScheduledAtUtc) SELECT HouseholdId,RecipientUserId,TemplateId,DedupeKey,PayloadJson,ScheduledAtUtc FROM notify.Outbox WHERE HouseholdId=1 AND Id=1;',2627,N'Duplicate notification delivery key rejected';
GO
-- Test actual grants with a loginless user. User creation and membership are rolled back.
BEGIN TRANSACTION;
CREATE USER AarohiPermissionTest WITHOUT LOGIN;
ALTER ROLE aarohi_app ADD MEMBER AarohiPermissionTest;
EXECUTE AS USER='AarohiPermissionTest';
DECLARE @Failed bit=0;
BEGIN TRY EXEC(N'SELECT TOP(1) CodeHmac FROM auth.AuthChallenge;'); END TRY BEGIN CATCH IF ERROR_NUMBER()=229 SET @Failed=1; ELSE THROW; END CATCH;
IF @Failed=0 BEGIN REVERT; ROLLBACK; THROW 52000,'FAIL: app role can read OTP hashes.',1; END;
SET @Failed=0;
BEGIN TRY EXEC(N'UPDATE audit.Event SET Summary=N''tampered'' WHERE HouseholdId=1;'); END TRY BEGIN CATCH IF ERROR_NUMBER()=229 SET @Failed=1; ELSE THROW; END CATCH;
IF @Failed=0 BEGIN REVERT; ROLLBACK; THROW 52000,'FAIL: app role can rewrite audit history.',1; END;
IF (SELECT COUNT(*) FROM cfg.vPublicSettings)=0 BEGIN REVERT; ROLLBACK; THROW 52000,'FAIL: public settings not readable.',1; END;
REVERT;
ROLLBACK;
PRINT 'PASS: application cannot read authentication secrets or rewrite audit history; public configuration remains readable.';
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=NULL;
PRINT 'ALL AAROHI DATABASE TESTS PASSED';
GO
