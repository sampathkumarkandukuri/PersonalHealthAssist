-- Run after 011; optional examples do not require demo rows.
SELECT l.Code,p.NativeName,p.Direction,p.IsInterfaceEnabled FROM cfg.LanguagePresentation p JOIN cfg.Language l ON l.Id=p.LanguageId WHERE p.IsInterfaceEnabled=1;
SELECT * FROM cfg.fnInterfaceText('ar');
SELECT Code,Label,Route,ParentId FROM cfg.Menu WHERE IsVisible=1 ORDER BY ParentId,SortOrder;
SELECT * FROM cfg.RouteAlias;
SELECT Code,Name,Category,WebsiteUrl,ConnectionMode,SupportsPriceLookup,SupportsCartTransfer FROM commerce.Provider WHERE IsEnabled=1 ORDER BY Category,Name;
SELECT i.Code,i.Name,p.CategoryCode,p.AccentColor,p.ImageState,m.StorageKey,m.AltText FROM food.Ingredient i LEFT JOIN food.IngredientPresentation p ON p.IngredientId=i.Id LEFT JOIN cfg.MediaAsset m ON m.Id=i.MediaId;
-- Trusted API must authorize household membership before this operation.
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=1;
SELECT * FROM finance.vPlanOverview;
SELECT g.Name,g.TargetBasis,COALESCE(g.TargetDate,DATEADD(year,g.TargetAge,p.DateOfBirth)) AS EffectiveTargetDate,g.CurrentCost,g.EarmarkedSavings FROM finance.PlanGoal g LEFT JOIN finance.PlanPerson p ON p.HouseholdId=g.HouseholdId AND p.ScenarioId=g.ScenarioId AND p.Id=g.PersonId;
SELECT * FROM commerce.vComparisonSummary;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=NULL;
