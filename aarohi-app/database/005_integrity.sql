SET NOCOUNT ON; SET XACT_ABORT ON; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;
GO
CREATE OR ALTER TRIGGER family.tr_Member_OptionGroup ON family.Member AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.DietOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'Diet') THROW 51001,'Wrong configuration option group for family.Member.DietOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER health.tr_Document_OptionGroup ON health.Document AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.CategoryOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'DocumentCategory') THROW 51001,'Wrong configuration option group for health.Document.CategoryOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER health.tr_Condition_OptionGroup ON health.Condition AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.ConditionOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'Condition') THROW 51001,'Wrong configuration option group for health.Condition.ConditionOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER health.tr_Allergy_OptionGroup ON health.Allergy AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.SeverityOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'Severity') THROW 51001,'Wrong configuration option group for health.Allergy.SeverityOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER health.tr_PrescriptionItem_OptionGroup ON health.PrescriptionItem AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.FormOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'MedicineForm') THROW 51001,'Wrong configuration option group for health.PrescriptionItem.FormOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER health.tr_Observation_OptionGroup ON health.Observation AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.MetricOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'Metric') THROW 51001,'Wrong configuration option group for health.Observation.MetricOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER food.tr_Recipe_OptionGroup ON food.Recipe AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.MealTypeOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'MealType') THROW 51001,'Wrong configuration option group for food.Recipe.MealTypeOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER pantry.tr_Movement_OptionGroup ON pantry.Movement AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.ReasonOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'StockReason') THROW 51001,'Wrong configuration option group for pantry.Movement.ReasonOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER notify.tr_Reminder_OptionGroup ON notify.Reminder AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.KindOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'ReminderKind') THROW 51001,'Wrong configuration option group for notify.Reminder.KindOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER commerce.tr_ShoppingItem_OptionGroup ON commerce.ShoppingItem AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.DosageFormOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'MedicineForm') THROW 51001,'Wrong configuration option group for commerce.ShoppingItem.DosageFormOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER finance.tr_Account_OptionGroup ON finance.Account AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.TypeOptionId JOIN cfg.OptionGroup g ON g.Id=o.GroupId WHERE g.Code<>'AccountType') THROW 51001,'Wrong configuration option group for finance.Account.TypeOptionId.',1;
END;
GO
CREATE OR ALTER TRIGGER finance.tr_IncomePlan_Category ON finance.IncomePlan AFTER INSERT,UPDATE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM inserted i JOIN finance.Category c ON c.Id=i.CategoryId WHERE c.Kind NOT IN ('Income')) THROW 51002,'Wrong financial category type.',1; END;
GO
CREATE OR ALTER TRIGGER finance.tr_Budget_Category ON finance.Budget AFTER INSERT,UPDATE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM inserted i JOIN finance.Category c ON c.Id=i.CategoryId WHERE c.Kind NOT IN ('Expense','Saving')) THROW 51002,'Wrong financial category type.',1; END;
GO
CREATE OR ALTER TRIGGER finance.tr_Liability_Category ON finance.Liability AFTER INSERT,UPDATE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM inserted i JOIN finance.Category c ON c.Id=i.CategoryId WHERE c.Kind NOT IN ('Liability')) THROW 51002,'Wrong financial category type.',1; END;
GO
CREATE OR ALTER TRIGGER finance.tr_Asset_Category ON finance.Asset AFTER INSERT,UPDATE AS BEGIN SET NOCOUNT ON; IF EXISTS(SELECT 1 FROM inserted i JOIN finance.Category c ON c.Id=i.CategoryId WHERE c.Kind NOT IN ('Asset')) THROW 51002,'Wrong financial category type.',1; END;
GO
CREATE OR ALTER TRIGGER cfg.tr_Menu_NoCycles ON cfg.Menu AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @bad int;
 ;WITH Ancestors AS (
 SELECT i.Id AS StartId,i.Id,i.ParentId,CAST('/'+CAST(i.Id AS varchar(20))+'/' AS varchar(max)) AS Trail,0 AS Depth,0 AS Cycle FROM inserted i
 UNION ALL
 SELECT a.StartId,p.Id,p.ParentId,CAST(a.Trail+CAST(p.Id AS varchar(20))+'/' AS varchar(max)),a.Depth+1,
 CASE WHEN CHARINDEX('/'+CAST(p.Id AS varchar(20))+'/',a.Trail)>0 THEN 1 ELSE 0 END
 FROM Ancestors a JOIN cfg.Menu p ON p.Id=a.ParentId WHERE a.Cycle=0 AND a.Depth<32
 ) SELECT @bad=COUNT(*) FROM Ancestors WHERE Cycle=1 OR (Depth=32 AND ParentId IS NOT NULL);
 IF @bad>0 THROW 51003,'Menu hierarchy contains a cycle or exceeds 32 levels.',1;
END;
GO
CREATE OR ALTER TRIGGER pantry.tr_Movement_Nonnegative ON pantry.Movement AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 -- Serialize validation per lot. Concurrent conflicts can deadlock and must be retried by the API.
 DECLARE @locked bigint;
 SELECT @locked=l.Id FROM pantry.StockLot l WITH(UPDLOCK,HOLDLOCK)
 JOIN (SELECT HouseholdId,StockLotId FROM inserted UNION SELECT HouseholdId,StockLotId FROM deleted) c ON c.HouseholdId=l.HouseholdId AND c.StockLotId=l.Id;
 IF EXISTS(SELECT m.HouseholdId,m.StockLotId FROM pantry.Movement m WITH(UPDLOCK,HOLDLOCK)
 JOIN (SELECT HouseholdId,StockLotId FROM inserted UNION SELECT HouseholdId,StockLotId FROM deleted) c ON c.HouseholdId=m.HouseholdId AND c.StockLotId=m.StockLotId
 GROUP BY m.HouseholdId,m.StockLotId HAVING SUM(m.QuantityDelta)<0)
 THROW 51004,'Stock movement would leave a negative lot balance.',1;
END;
GO
CREATE OR ALTER TRIGGER pantry.tr_StockLot_StableUnit ON pantry.StockLot AFTER UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON i.HouseholdId=d.HouseholdId AND i.Id=d.Id
 WHERE (i.IngredientId<>d.IngredientId OR i.UnitId<>d.UnitId) AND EXISTS(SELECT 1 FROM pantry.Movement m WHERE m.HouseholdId=i.HouseholdId AND m.StockLotId=i.Id))
 THROW 51005,'Ingredient and unit cannot change after movements exist; create a new lot.',1;
END;
GO
CREATE OR ALTER TRIGGER notify.tr_Reminder_Prescription ON notify.Reminder AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN cfg.[Option] o ON o.Id=i.KindOptionId WHERE (o.Code='medicine' AND i.PrescriptionItemId IS NULL) OR (o.Code<>'medicine' AND i.PrescriptionItemId IS NOT NULL))
 THROW 51006,'Medicine reminders require their member prescription item; other reminders cannot reference one.',1;
END;
GO
CREATE OR ALTER TRIGGER commerce.tr_Quote_ProviderCategory ON commerce.Quote AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN commerce.ShoppingList l ON l.HouseholdId=i.HouseholdId AND l.Id=i.ShoppingListId JOIN commerce.Provider p ON p.Id=i.ProviderId
 WHERE (l.Kind='Medicine' AND p.Category<>'Pharmacy') OR (l.Kind='Grocery' AND p.Category<>'Grocery')) THROW 51007,'Provider category does not match shopping list.',1;
END;
GO
CREATE OR ALTER TRIGGER commerce.tr_Order_ProviderCategory ON commerce.OrderRecord AFTER INSERT,UPDATE AS
BEGIN SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN commerce.ShoppingList l ON l.HouseholdId=i.HouseholdId AND l.Id=i.ShoppingListId JOIN commerce.Provider p ON p.Id=i.ProviderId
 WHERE (l.Kind='Medicine' AND p.Category<>'Pharmacy') OR (l.Kind='Grocery' AND p.Category<>'Grocery')) THROW 51007,'Provider category does not match shopping list.',1;
END;
GO
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='005') INSERT dbo.SchemaMigration(Version) VALUES('005');
GO
