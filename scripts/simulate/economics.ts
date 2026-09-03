import {mkdir, writeFile} from "node:fs/promises";
import {join} from "node:path";

/** Deterministic protocol-rule scenario model; this is explicitly not a forecast. */
type Day={day:number;users:number;newUsers:number;positionValue:number;liquidityAddedUsdt:number;pairAlpReserve:number;burn:number;emission:number;globalCompute:number;newUserCompute:number;linearTimeCompensation:number;userSellGross:number;sellFee:number;buyback:number;top100:number;nodeAirdrop:number;community:number;development:number;circulatingAlp:number;genesisReserve:number};
type Scenario={name:string;targetUsers:number;dailyGrowth:"linear"|"front-loaded"};
const scenarios:Scenario[]=[{name:"100-users",targetUsers:100,dailyGrowth:"linear"},{name:"1000-users",targetUsers:1_000,dailyGrowth:"linear"},{name:"10000-users",targetUsers:10_000,dailyGrowth:"front-loaded"},{name:"100000-users",targetUsers:100_000,dailyGrowth:"front-loaded"}];
const initialPairAlp=3_000_000, initialGenesis=207_000_000, positionValuePerUser=1_000;
const outputRate=(day:number)=>day>=60?0.012:0.006+(day-1)*0.0001;
function runScenario(scenario:Scenario):Day[] {
  const rows:Day[]=[]; let users=0,pairAlpReserve=initialPairAlp,genesisReserve=initialGenesis,circulatingAlp=0,globalCompute=0;
  for(let day=1;day<=365;day++) {
    const progress=day/365, desired=scenario.dailyGrowth==="linear"?scenario.targetUsers*progress:scenario.targetUsers*(1-Math.pow(1-progress,2));
    const nextUsers=Math.min(scenario.targetUsers,Math.max(users,Math.round(desired))),newUsers=nextUsers-users; users=nextUsers;
    const positionValue=newUsers*positionValuePerUser, liquidityAddedUsdt=positionValue*0.25;
    const linearTimeCompensation=1+Math.min(364,day-1)/365, newUserCompute=positionValue*linearTimeCompensation; globalCompute+=newUserCompute;
    const reserveBefore=pairAlpReserve, burn=reserveBefore*0.012, emission=reserveBefore*outputRate(day); pairAlpReserve-=burn+emission; circulatingAlp+=emission;
    // Scenario assumption: 0.20% of circulating ALP is sold daily; protocol fee split is exact 5/1/4/5/2.
    const userSellGross=circulatingAlp*0.002, sellFee=userSellGross*0.17, buyback=sellFee*5/17, top100=sellFee/17, nodeAirdrop=sellFee*4/17, community=sellFee*5/17, development=sellFee*2/17;
    circulatingAlp=Math.max(0,circulatingAlp-userSellGross); pairAlpReserve+=userSellGross-sellFee;
    rows.push({day,users,newUsers,positionValue,liquidityAddedUsdt,pairAlpReserve,burn,emission,globalCompute,newUserCompute,linearTimeCompensation,userSellGross,sellFee,buyback,top100,nodeAirdrop,community,development,circulatingAlp,genesisReserve});
  }
  return rows;
}
const columns=["day","users","newUsers","positionValue","liquidityAddedUsdt","pairAlpReserve","burn","emission","globalCompute","newUserCompute","linearTimeCompensation","userSellGross","sellFee","buyback","top100","nodeAirdrop","community","development","circulatingAlp","genesisReserve"] as const;
async function main(){
  const output=join(process.cwd(),"artifacts","economics"); await mkdir(output,{recursive:true}); const summaries=[] as Record<string,unknown>[];
  for(const scenario of scenarios){const rows=runScenario(scenario),last=rows.at(-1)!; await writeFile(join(output,`${scenario.name}.csv`),[columns.join(","),...rows.map(row=>columns.map(column=>row[column]).join(","))].join("\n")); summaries.push({scenario:scenario.name,assumptions:{positionValuePerUser,initialPairAlp,initialGenesis,sellRateOfCirculatingPerDay:0.002,sellFeeBps:1700,burnBps:120,emissionDay1Bps:60,emissionDay60Bps:120},final:last});}
  await writeFile(join(output,"summary.json"),JSON.stringify({disclaimer:"Scenario analysis only; not a forecast, yield promise, or investment return estimate.",summaries},null,2));
  const max=Math.max(...summaries.map(item=>Number((item.final as Day).users))); const paths=scenarios.map((scenario,index)=>{const rows=runScenario(scenario);return `<path d="${rows.map((row,i)=>`${i?"L":"M"}${i/364*900+60},${350-row.users/max*280}`).join(" ")}" fill="none" stroke="hsl(${150+index*45} 75% 58%)" stroke-width="3"/>`;}).join("");
  await writeFile(join(output,"users.svg"),`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 400"><rect width="1000" height="400" fill="#07111f"/><text x="40" y="42" fill="#eaf5ff" font-family="sans-serif" font-size="22">ALP protocol scenarios — users (not a forecast)</text>${paths}</svg>`);
  console.log(JSON.stringify({output,scenarios:summaries.map(summary=>summary.scenario)}));
}
void main();
