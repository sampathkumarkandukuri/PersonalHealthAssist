-- Read-only examples for the fictional household. In the API, validate membership FIRST.
SET QUOTED_IDENTIFIER ON;
EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=1;

-- 1. Configurable navigation, submenus and permission requirement.
SELECT m.Id,m.ParentId,m.Code,m.Label,m.Route,m.IconKey,m.BackgroundColor,m.ForegroundColor,
       p.Code AS RequiredPermission,f.Code AS FeatureCode,f.IsEnabled AS FeatureEnabled
FROM cfg.Menu m LEFT JOIN auth.Permission p ON p.Id=m.PermissionId LEFT JOIN cfg.Feature f ON f.Id=m.FeatureId
WHERE m.IsVisible=1 ORDER BY m.SortOrder,m.Id;

-- 2. Selected state -> cuisines -> meals -> configurable photographs.
SELECT r.Name AS Region,c.Name AS Cuisine,re.Name AS Recipe,re.IsPlaceholder,re.ReviewStatus,
       a.StorageProvider,a.StorageKey,a.AltText,re.IndicativeCostINR
FROM cfg.Region r JOIN cfg.Cuisine c ON c.RegionId=r.Id
JOIN food.RecipeCuisine rc ON rc.CuisineId=c.Id JOIN food.Recipe re ON re.Id=rc.RecipeId
JOIN cfg.MediaAsset a ON a.Id=re.MediaId WHERE r.Name=N'Telangana'
ORDER BY c.SortOrder,rc.SortOrder;

-- 3. DOB is authoritative; age is calculated at an explicit date.
DECLARE @AsOfDate date='2026-10-24';
SELECT Name,BirthDate,
 DATEDIFF(year,BirthDate,@AsOfDate)-CASE WHEN DATEADD(year,DATEDIFF(year,BirthDate,@AsOfDate),BirthDate)>@AsOfDate THEN 1 ELSE 0 END AS Age
FROM family.Member;

-- 4. Stock is a movement ledger; expiry belongs to each batch, not the ingredient.
SELECT * FROM pantry.vLotBalance;
SELECT * FROM pantry.fnAlerts(@AsOfDate) WHERE IsLowStock=1 OR IsRunOutSoon=1 OR IsExpiryWarning=1;

-- 5. Persisted local reminder times. Monday=1 ... Sunday=64; 127 = every day.
SELECT m.Name,r.Title,r.TimeZoneIana,t.LocalTime,t.WeekdayMask,r.StartDate,r.EndDate,r.IsEnabled
FROM notify.Reminder r JOIN family.Member m ON m.HouseholdId=r.HouseholdId AND m.Id=r.MemberId
JOIN notify.ReminderTime t ON t.HouseholdId=r.HouseholdId AND t.ReminderId=r.Id;

-- 6. Sample quotes are EXPIRED, illustrative and have unknown stock; never present them as live.
SELECT p.Name,q.*,CASE WHEN q.ExpiresAtUtc>SYSUTCDATETIME() THEN 0 ELSE 1 END AS IsExpired
FROM commerce.vQuoteTotal q JOIN commerce.Provider p ON p.Id=q.ProviderId ORDER BY q.Total;

-- 7. Budgets and savings are computed from entries rather than duplicate mutable totals.
SELECT * FROM finance.vBudgetActual;
SELECT * FROM finance.vGoalProgress;

-- 8. Configurable pharmacy website handoff; no prescription transfer.
SELECT Name,WebsiteUrl,ConnectionMode,SupportsPriceLookup,SupportsCartTransfer
FROM commerce.Provider WHERE Category='Pharmacy' AND IsEnabled=1;

EXEC sys.sp_set_session_context @key=N'HouseholdId',@value=NULL;
