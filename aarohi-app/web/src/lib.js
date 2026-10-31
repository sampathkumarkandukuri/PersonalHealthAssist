let accessToken='';
export function setToken(value){accessToken=value}
export async function api(path,options={}){const headers={...(accessToken?{Authorization:`Bearer ${accessToken}`}:{})};if(options.body&&!(options.body instanceof FormData)){headers['Content-Type']='application/json';options={...options,body:JSON.stringify(options.body)}}const r=await fetch('/api'+path,{...options,headers:{...headers,...options.headers}});if(r.status===204)return null;const data=await r.json().catch(()=>({error:'Unexpected server response'}));if(!r.ok)throw new Error(data.error||`Request failed (${r.status})`);return data}
export const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export const money=(n,c='INR')=>new Intl.NumberFormat('en-IN',{style:'currency',currency:c,maximumFractionDigits:0}).format(n||0);
export function monthlySaving(cost,saved,annual,months){if(months<=0)return null;const r=Math.pow(1+annual/100,1/12)-1;return Math.max(0,cost-saved*Math.pow(1+r,months))/(Math.abs(r)<1e-10?months:(Math.pow(1+r,months)-1)/r)}
export function goalProjection(goal,people,asOf){const p=people.find(p=>p.Id===goal.PersonId);let date=goal.TargetDate;if(goal.TargetBasis==='Age'&&p){const birth=new Date(p.DateOfBirth);birth.setUTCFullYear(birth.getUTCFullYear()+goal.TargetAge);date=birth.toISOString()}const months=Math.max(0,Math.ceil((Date.parse(date)-Date.parse(asOf))/(365.25/12*86400000)));const target=goal.CurrentCost*Math.pow(1+goal.InflationPercent/100,months/12);return {months,target,sip:monthlySaving(target,goal.EarmarkedSavings,goal.ReturnPercent,months)}}
export function compareBasket(products,offers,providers,quantities){return providers.filter(p=>p.Category==='Grocery').map(p=>{let subtotal=0,count=0,missing=0;for(const product of products){const n=quantities[product.Id]||0;count+=n;const offer=offers.find(o=>o.ProductId===product.Id&&o.ProviderId===p.Id);if(offer?.PackPrice==null)missing+=n;else subtotal+=n*offer.PackPrice}return {...p,subtotal,count,missing}})}
export function parseExpenses(text,date=today()){const categories=[[/grocer|milk|rice|vegetable/i,'groceries'],[/lunch|dinner|breakfast|coffee|restaurant/i,'dining'],[/taxi|bus|train|fuel|uber/i,'transport'],[/rent/i,'housing'],[/medicine|doctor/i,'health'],[/bill|electric/i,'bills']];return text.split(/[,;\n]+/).filter(s=>s.trim()).map(part=>{const match=part.trim().match(/^(.+?)\s*[₹]?\s*(\d+(?:\.\d{1,2})?)$/);if(!match||/[$€]/.test(part))throw new Error('Use INR and one amount per entry: Lunch 150; groceries 800. Use the detailed form for transfers and refunds.');if(/refund|transfer|salary|income|credit.card/i.test(match[1]))throw new Error('Use the detailed form to select the transaction type.');return {OccurredOn:date,Description:match[1].trim(),Category:categories.find(([re])=>re.test(match[1]))?.[1]||'other',Amount:Number(match[2]),Kind:'Expense'}})}
export function retirementProjection(plan,people,summary){const person=people.find(p=>p.ScenarioId===plan.Id&&p.IsRetirementPerson);if(!person)return {error:'Select a retirement person in Family & goals.'};const asOf=new Date(plan.AsOfDate),birth=new Date(person.DateOfBirth);const age=(asOf-birth)/(365.25*86400000),months=Math.max(0,Math.ceil((person.RetirementAge-age)*12)),retirementMonths=(plan.EndAge-person.RetirementAge)*12;if(months<=0||retirementMonths<=0)return {error:'Retirement age must be after current age and before the plan end age.'};const before=Math.pow(1+plan.BeforeReturnPercent/100,1/12)-1,after=Math.pow(1+plan.AfterReturnPercent/100,1/12)-1,inflation=Math.pow(1+plan.InflationPercent/100,1/12)-1;const spending=(summary.Essential+summary.Lifestyle)*plan.RetireSpendPercent/100*Math.pow(1+inflation,months);let corpus=0;for(let m=0;m<retirementMonths;m++)corpus+=Math.max(0,spending*Math.pow(1+inflation,m)-plan.MonthlyPension)/Math.pow(1+after,m);const factor=Math.abs(before)<1e-10?months:(Math.pow(1+before,months)-1)/before;const projected=plan.RetireSaved*Math.pow(1+before,months)+plan.RetireContribution*factor;let balance=projected,unfunded=0,rows=[];for(let m=0;m<retirementMonths;m++){const opening=balance,expense=Math.max(0,spending*Math.pow(1+inflation,m)-plan.MonthlyPension),shortfall=Math.max(0,expense-balance);unfunded+=shortfall;balance=Math.max(0,balance-expense)*(1+after);if(m%12===0)rows.push({age:person.RetirementAge+m/12,opening,expense,closing:balance})}return {spending,corpus,projected,sip:monthlySaving(corpus,plan.RetireSaved,plan.BeforeReturnPercent,months),unfunded,rows}}

// External search navigation only: this does not retrieve prices or stock.
export function providerSearch(provider,term){
 const query=term.trim();
 let site;try{site=new URL(provider.WebsiteUrl)}catch{return null}
 if(site.protocol!=='https:')return null;
 if(!query)return {url:site.href,kind:'website'};
 const host=site.hostname.replace(/^www\./,'');
 const routes={
  'blinkit.com':['https://blinkit.com/s/','q'],
  'bigbasket.com':['https://www.bigbasket.com/ps/','q'],
  'zeptonow.com':['https://www.zepto.com/search','query'],
  'zepto.com':['https://www.zepto.com/search','query']
 };
 const route=routes[host];
 const url=new URL(route?route[0]:'https://www.google.com/search');
 url.searchParams.set(route?route[1]:'q',route?query:'site:'+host+' '+query);
 return {url:url.href,kind:route?'retailer':'web'};
}
