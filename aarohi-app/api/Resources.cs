using System.Security.Claims;
using System.Text.Json;
using Microsoft.Data.SqlClient;
namespace Aarohi;
public record Resource(string Table,string Fields,string Read,string Write,bool Medical=false,bool ReadOnly=false){public string[] Columns=>Fields.Split(',');}
public static class Resources
{
 public static readonly Dictionary<string,Resource> All=new(){
 ["members"]=new("family.Member","Name,BirthDate,Relationship,DietOptionId,IsActive","household.read","household.manage"),
 ["conditions"]=new("health.Condition","MemberId,ConditionOptionId,RecordedDate,Notes,IsActive","health.read","health.write",true),
 ["allergies"]=new("health.Allergy","MemberId,AllergenId,Reaction,SeverityOptionId,IsActive","health.read","health.write",true),
 ["instructions"]=new("health.DietInstruction","MemberId,Instruction,AuthorLabel,ValidFrom,ValidUntil","health.read","health.write",true),
 ["observations"]=new("health.Observation","MemberId,MetricOptionId,ObservedAt,NumericValue,TextValue,UnitId","health.read","health.write",true),
 ["prescriptions"]=new("health.Prescription","MemberId,DocumentId,PrescribedOn,ValidUntil,ClinicianLabel","health.read","health.write",true),
 ["prescription-items"]=new("health.PrescriptionItem","MemberId,PrescriptionId,MedicineName,Strength,FormOptionId,PackDescription,Instructions,StartDate,EndDate,IsActive","health.read","health.write",true),
 ["meal-plans"]=new("food.MealPlan","MemberId,RecipeId,PlannedDate,LocalTime,Servings,Status","household.read","household.manage"),
 ["stock"]=new("pantry.StockLot","IngredientId,LotCode,UnitId,PurchasedOn,ExpiresOn,StorageLocation","pantry.read","pantry.write"),
 ["stock-rules"]=new("pantry.AlertRule","IngredientId,UnitId,LowStockQuantity,DailyUsageQuantity,ExpiryLeadDays,RunOutLeadDays,IsEnabled","pantry.read","pantry.write"),
 ["reminders"]=new("notify.Reminder","MemberId,KindOptionId,PrescriptionItemId,Title,Instructions,StartDate,EndDate,IsEnabled","reminders.manage","reminders.manage",true),
 ["reminder-times"]=new("notify.ReminderTime","ReminderId,LocalTime,WeekdayMask","reminders.manage","reminders.manage"),
 ["shopping-lists"]=new("commerce.ShoppingList","Name,Kind,Status","shopping.manage","shopping.manage"),
 ["shopping-items"]=new("commerce.ShoppingItem","ShoppingListId,Kind,IngredientId,MemberId,PrescriptionItemId,Description,Quantity,UnitId,Strength,DosageFormOptionId,PackDescription,IsChecked","shopping.manage","shopping.manage"),
 ["budgets"]=new("finance.Budget","MonthStart,CategoryId,Amount","finance.read","finance.write"),
 ["expenses"]=new("finance.ExpenseEntry","OccurredOn,Description,Category,Amount,Kind,PaymentMethod,OriginalExpenseId,GoalId","finance.read","finance.write"),
 ["goals"]=new("finance.SavingsGoal","Name,TargetAmount,MonthlyAllocation,TargetDate,OpeningSavedAmount,Status","finance.read","finance.write"),
 ["plans"]=new("finance.PlanScenario","Name,CurrencyCode,AsOfDate,InflationPercent,BeforeReturnPercent,AfterReturnPercent,EndAge,RetireSpendPercent,RetireSaved,RetireContribution,MonthlyPension,EmergencyMonths,EmergencySaved,EmergencyContribution,SupportYears,SupportDiscountPercent,SupportAssets,HealthCoverTarget","finance.read","finance.write"),
 ["plan-people"]=new("finance.PlanPerson","ScenarioId,MemberId,Name,DateOfBirth,RetirementAge,IsRetirementPerson","finance.read","finance.write"),
 ["plan-assets"]=new("finance.PlanAsset","ScenarioId,Name,AssetType,CurrentValue","finance.read","finance.write"),
 ["plan-debts"]=new("finance.PlanDebt","ScenarioId,Name,OutstandingBalance,MonthlyEmi,InterestPercent,RemainingMonths","finance.read","finance.write"),
 ["plan-flows"]=new("finance.PlanFlow","ScenarioId,Name,Kind,Amount","finance.read","finance.write"),
 ["plan-policies"]=new("finance.PlanPolicy","ScenarioId,Name,Kind,CoverAmount,AnnualPremium","finance.read","finance.write"),
 ["plan-goals"]=new("finance.PlanGoal","ScenarioId,PersonId,Name,CurrentCost,EarmarkedSavings,TargetBasis,TargetDate,TargetAge,InflationPercent,ReturnPercent","finance.read","finance.write")};
 static Resource Get(string key)=>All.TryGetValue(key,out var r)?r:throw new ApiError(404,"Unknown resource.");
 static string Projection(Resource r)=>"Id,Version,"+r.Fields;
 public static async Task Guard(Db db,ClaimsPrincipal user,string permission){if(!await db.Permission(user,permission))throw new ApiError(403,"Your role does not permit this action.");}
 static async Task GuardMember(SqlConnection c,ClaimsPrincipal user,long member){if(await Db.Scalar(c,$"SELECT COUNT(*) FROM family.Member WHERE Id=@m AND (UserId=@u OR Id IN(SELECT MemberId FROM family.MemberAccess WHERE UserId=@u AND PermissionId IN(SELECT Id FROM auth.Permission WHERE Code='health.write') AND RevokedAt IS NULL AND (ExpiresAt IS NULL OR ExpiresAt>SYSUTCDATETIME())))",new(){["m"]=member,["u"]=Db.User(user)})==0)throw new ApiError(403,"This health profile has not been shared with you.");}
 public static void MapResources(this WebApplication app){
 app.MapGet("/api/data/{key}",async(string key,ClaimsPrincipal u,Db db)=>{var r=Get(key);await Guard(db,u,r.Read);await using var c=await db.Open(Db.Household(u));string filter=r.Medical?" AND "+Db.MemberAccess:"";if(key=="shopping-items")filter+=" AND (MemberId IS NULL OR "+Db.MemberAccess+")";if(key=="reminder-times")filter+=" AND ReminderId IN(SELECT Id FROM notify.Reminder WHERE "+Db.MemberAccess+")";return Results.Ok(await Db.Query(c,$"SELECT TOP(500) {Projection(r)} FROM {r.Table} WHERE HouseholdId=@h {filter} ORDER BY Id DESC",new(){["h"]=Db.Household(u),["actor"]=Db.User(u)}));}).RequireAuthorization();
 app.MapGet("/api/forms/{key}",async(string key,ClaimsPrincipal u,Db db)=>{var r=Get(key);await Guard(db,u,r.Read);await using var c=await db.Open();var columns=await Db.Query(c,"SELECT c.name Name,t.name SqlType,c.is_nullable Nullable,c.max_length MaxLength,CONVERT(bit,CASE WHEN c.default_object_id<>0 THEN 1 ELSE 0 END) HasDefault FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id WHERE c.object_id=OBJECT_ID(@table)",new(){["table"]=r.Table});return Results.Ok(new{fields=r.Columns.Select(n=>columns.First(x=>(string)x["Name"]! ==n)),canWrite=await db.Permission(u,r.Write)});}).RequireAuthorization();
 app.MapPost("/api/data/{key}",async(string key,Dictionary<string,JsonElement> body,ClaimsPrincipal u,Db db)=>await Save(key,null,body,u,db)).RequireAuthorization();
 app.MapPut("/api/data/{key}/{id:long}",async(string key,long id,Dictionary<string,JsonElement> body,ClaimsPrincipal u,Db db)=>await Save(key,id,body,u,db)).RequireAuthorization();
 app.MapDelete("/api/data/{key}/{id:long}",async(string key,long id,string version,ClaimsPrincipal u,Db db)=>{var r=Get(key);await Guard(db,u,r.Write);await using var c=await db.Open(Db.Household(u));if(r.Medical){var rows=await Db.Query(c,$"SELECT MemberId FROM {r.Table} WHERE Id=@id",new(){["id"]=id});if(rows.Count==0)return Results.NotFound();await GuardMember(c,u,Convert.ToInt64(rows[0]["MemberId"]));}if(key is "shopping-items" or "reminder-times")throw new ApiError(400,"Archive the shopping list or disable its reminder instead.");var count=await Db.Exec(c,$"DELETE FROM {r.Table} WHERE Id=@id AND HouseholdId=@h AND Version=@v",new(){["id"]=id,["h"]=Db.Household(u),["v"]=Convert.FromBase64String(version)});return count==1?Results.NoContent():Results.Conflict(new{error="Record changed. Refresh and try again."});}).RequireAuthorization();
 }
 static async Task<IResult> Save(string key,long? id,Dictionary<string,JsonElement> body,ClaimsPrincipal u,Db db){var r=Get(key);await Guard(db,u,r.Write);await using var c=await db.Open(Db.Household(u));var values=new Dictionary<string,object?>();foreach(var (name,val) in body){if(name is "_version" or "GrantCreatorAccess")continue;if(!r.Columns.Contains(name))throw new ApiError(400,"Unexpected field: "+name);values[name]=val.ValueKind switch{JsonValueKind.Null=>null,JsonValueKind.True=>true,JsonValueKind.False=>false,JsonValueKind.Number=>val.GetDecimal(),JsonValueKind.String=>val.GetString(),_=>throw new ApiError(400,"Invalid field value.")};}
 if(values.Count==0)throw new ApiError(400,"Enter at least one field.");
 if(id.HasValue){var prior=await Db.Query(c,$"SELECT * FROM {r.Table} WHERE Id=@id",new(){["id"]=id});if(prior.Count==0)throw new ApiError(404,"Record not found.");if(r.Medical||(key=="shopping-items"&&prior[0]["MemberId"]!=null))await GuardMember(c,u,Convert.ToInt64(prior[0]["MemberId"]));if(key=="reminder-times"){var oldReminder=await Db.Query(c,"SELECT MemberId FROM notify.Reminder WHERE Id=@id",new(){["id"]=prior[0]["ReminderId"]});if(oldReminder.Count==0)throw new ApiError(403,"Reminder access required.");await GuardMember(c,u,Convert.ToInt64(oldReminder[0]["MemberId"]));}}
 if((r.Medical||key=="shopping-items")&&values.GetValueOrDefault("MemberId") is object m)await GuardMember(c,u,Convert.ToInt64(m));
 if(key=="reminder-times"){var rid=values.GetValueOrDefault("ReminderId");if(rid==null)throw new ApiError(400,"Reminder is required.");var rows=await Db.Query(c,"SELECT MemberId FROM notify.Reminder WHERE Id=@id",new(){["id"]=rid});if(rows.Count==0)throw new ApiError(404,"Reminder not found.");await GuardMember(c,u,Convert.ToInt64(rows[0]["MemberId"]));}
 if(key=="members"&&values.GetValueOrDefault("BirthDate") is string birth&&DateTime.Parse(birth)>DateTime.UtcNow)throw new ApiError(400,"Birth date cannot be in the future.");
 if(key=="expenses"&&values.GetValueOrDefault("OccurredOn") is string date&&DateTime.Parse(date).Date>DateTime.UtcNow.AddHours(5.5).Date)throw new ApiError(400,"Future expense dates are not supported.");
 if(key=="plans"&&values.GetValueOrDefault("CurrencyCode") is string currency&&!new[]{"INR","USD","EUR","GBP","AED","SAR"}.Contains(currency))throw new ApiError(400,"Unsupported currency.");
 var fields=values.Keys.ToArray();values["h"]=Db.Household(u);long saved;
 if(id.HasValue){if(!body.TryGetValue("_version",out var version))throw new ApiError(409,"Refresh the record before saving.");values["v"]=Convert.FromBase64String(version.GetString()!);values["id"]=id;var rows=await Db.Query(c,$"UPDATE {r.Table} SET {string.Join(',',fields.Select(f=>$"[{f}]=@{f}"))} OUTPUT inserted.Id WHERE Id=@id AND HouseholdId=@h AND Version=@v",values);if(rows.Count==0)throw new ApiError(409,"Record changed. Refresh and try again.");saved=id.Value;}
 else{var extras="";var extraValues="";if(key is "shopping-lists" or "expenses"){extras=",CreatedByUserId";extraValues=",@actor";}if(key=="observations"){extras=",RecordedByUserId";extraValues=",@actor";}values["actor"]=Db.User(u);saved=await Db.Scalar(c,$"INSERT {r.Table}(HouseholdId,{string.Join(',',fields.Select(f=>$"[{f}]"))}{extras}) OUTPUT inserted.Id VALUES(@h,{string.Join(',',fields.Select(f=>"@"+f))}{extraValues})",values);if(key=="members"&&body.TryGetValue("GrantCreatorAccess",out var grant)&&grant.ValueKind==JsonValueKind.True)await Db.Exec(c,"INSERT family.MemberAccess(HouseholdId,MemberId,UserId,PermissionId,GrantedByUserId) SELECT @h,@m,@u,Id,@u FROM auth.Permission WHERE Code IN ('health.read','health.write','health.documents'); INSERT family.Consent(HouseholdId,MemberId,ActorUserId,PurposeCode,PolicyVersion,GrantedAt) VALUES(@h,@m,@u,'profile-management','1',SYSUTCDATETIME())",new(){["h"]=Db.Household(u),["m"]=saved,["u"]=Db.User(u)});}
 return Results.Ok(new{id=saved});
 }
}

