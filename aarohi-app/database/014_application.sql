SET NOCOUNT ON; SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='014-app') RETURN;
BEGIN TRANSACTION;
CREATE TABLE auth.LocalCredential(UserId bigint PRIMARY KEY REFERENCES auth.UserAccount(Id),PasswordHash nvarchar(500) NOT NULL,FailedAttempts int NOT NULL DEFAULT 0,LockedUntil datetime2 NULL);
CREATE TABLE auth.UserHousehold(UserId bigint NOT NULL REFERENCES auth.UserAccount(Id),HouseholdId bigint NOT NULL REFERENCES family.Household(Id),PRIMARY KEY(UserId,HouseholdId));
INSERT auth.TokenPolicy(Code,Issuer,Audience,Algorithm,AccessTtlSeconds,RefreshTtlDays,SigningKeyReference,IsEnabled) VALUES('aarohi-web','aarohi-api','aarohi-web','RS256',1800,1,'environment:Jwt__PrivateKeyPath',1);
CREATE TABLE finance.ExpenseEntry(HouseholdId bigint NOT NULL REFERENCES family.Household(Id),Id bigint IDENTITY NOT NULL,OccurredOn date NOT NULL,Description nvarchar(250) NOT NULL,Category varchar(40) NOT NULL,Amount decimal(18,2) NOT NULL CHECK(Amount>0),Kind varchar(30) NOT NULL CHECK(Kind IN ('Expense','Income','Refund','Transfer','Savings transfer','Savings withdrawal','Credit-card payment')),PaymentMethod nvarchar(60) NULL,OriginalExpenseId bigint NULL,GoalId bigint NULL,CreatedByUserId bigint NOT NULL,Version rowversion NOT NULL,PRIMARY KEY(HouseholdId,Id),FOREIGN KEY(HouseholdId,OriginalExpenseId) REFERENCES finance.ExpenseEntry(HouseholdId,Id),FOREIGN KEY(HouseholdId,GoalId) REFERENCES finance.SavingsGoal(HouseholdId,Id),FOREIGN KEY(HouseholdId,CreatedByUserId) REFERENCES family.Membership(HouseholdId,UserId),CHECK(OriginalExpenseId IS NULL OR (Kind='Refund' AND OriginalExpenseId<>Id)),CHECK(GoalId IS NULL OR Kind IN ('Savings transfer','Savings withdrawal')));
EXEC(N'ALTER SECURITY POLICY auth.HouseholdIsolation ADD FILTER PREDICATE auth.fnHouseholdAccess(HouseholdId) ON finance.ExpenseEntry,ADD BLOCK PREDICATE auth.fnHouseholdAccess(HouseholdId) ON finance.ExpenseEntry AFTER INSERT,ADD BLOCK PREDICATE auth.fnHouseholdAccess(HouseholdId) ON finance.ExpenseEntry AFTER UPDATE;');
INSERT dbo.SchemaMigration(Version) VALUES('014-app'); COMMIT;
GO
CREATE OR ALTER TRIGGER finance.trExpenseRefund ON finance.ExpenseEntry AFTER INSERT,UPDATE,DELETE AS
BEGIN
SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM finance.ExpenseEntry r JOIN finance.ExpenseEntry e WITH(UPDLOCK,HOLDLOCK) ON e.HouseholdId=r.HouseholdId AND e.Id=r.OriginalExpenseId WHERE r.Kind='Refund' AND (e.Kind<>'Expense' OR r.Category<>e.Category OR r.OccurredOn<e.OccurredOn)) THROW 52300,'Refund must match the original expense and category/date.',1;
IF EXISTS(SELECT e.Id FROM finance.ExpenseEntry e WITH(UPDLOCK,HOLDLOCK) JOIN finance.ExpenseEntry r ON r.HouseholdId=e.HouseholdId AND r.OriginalExpenseId=e.Id GROUP BY e.Id,e.Amount HAVING SUM(r.Amount)>e.Amount) THROW 52300,'Refund exceeds recorded expense.',1;
END;
GO
CREATE OR ALTER VIEW finance.vRecordedSpending AS SELECT HouseholdId,Id,OccurredOn,Category,CASE WHEN Kind='Expense' THEN Amount WHEN Kind='Refund' AND OriginalExpenseId IS NOT NULL THEN -Amount ELSE 0 END NetSpent FROM finance.ExpenseEntry;
GO
