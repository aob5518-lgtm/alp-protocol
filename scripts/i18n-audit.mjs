import ts from "typescript";
import {readFile,readdir} from "node:fs/promises";
import {resolve,relative} from "node:path";
import {fileURLToPath} from "node:url";

const root=fileURLToPath(new URL("../",import.meta.url));
const en=JSON.parse(await readFile(resolve(root,"apps/web/messages/en-US.json"),"utf8"));
const zh=JSON.parse(await readFile(resolve(root,"apps/web/messages/zh-CN.json"),"utf8"));
const errors=[];
const keys=(obj,prefix="")=>Object.entries(obj).flatMap(([k,v])=>typeof v==="string"?[prefix+k]:keys(v,prefix+k+"."));
const enKeys=keys(en),zhKeys=keys(zh);
for(const key of new Set([...enKeys,...zhKeys])){
  if(!enKeys.includes(key)||!zhKeys.includes(key))errors.push("Unpaired translation: "+key);
}
const get=(obj,key)=>key.split(".").reduce((current,k)=>current?.[k],obj);
for(const key of enKeys){
  const a=get(en,key),b=get(zh,key);
  if(!a?.trim()||!b?.trim())errors.push("Empty translation: "+key);
  if(JSON.stringify(a.match(/\{\w+\}/g)?.sort()??[])!==JSON.stringify(b?.match(/\{\w+\}/g)?.sort()??[]))errors.push("Interpolation mismatch: "+key);
}
const brand=/^(ALP|RELIQUE|CARD|USDT|RWA|AI|IP|Web3|TOP100|BSC Testnet|V[1-9]|A)$/;
function visibleLiteral(value){
  if(brand.test(value.trim()))return false;
  const cleaned=value.replace(/[→↗:·+%\d\s.,…—/()-]/g," ").trim();
  return /[A-Za-z\u3400-\u9fff]/.test(cleaned)&&!cleaned.split(/\s+/).every(word=>brand.test(word));
}
async function walk(dir){
  for(const entry of await readdir(dir,{withFileTypes:true})){
    const path=resolve(dir,entry.name);
    if(entry.isDirectory()){await walk(path);continue;}
    if(!path.endsWith(".tsx"))continue;
    const source=await readFile(path,"utf8");
    const file=ts.createSourceFile(path,source,ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
    const bindings=new Map();
    const scopeOf=node=>{let scope=node.parent;while(scope&&!ts.isFunctionDeclaration(scope)&&!ts.isFunctionExpression(scope)&&!ts.isArrowFunction(scope))scope=scope.parent;return scope?.pos??-1;};
    function collect(node){
      if(ts.isVariableDeclaration(node)&&ts.isIdentifier(node.name)&&node.initializer&&ts.isCallExpression(node.initializer)&&node.initializer.expression.getText(file)==="useTranslations"){
        const arg=node.initializer.arguments[0];if(arg&&ts.isStringLiteral(arg))bindings.set(scopeOf(node)+":"+node.name.text,arg.text);
      }
      ts.forEachChild(node,collect);
    }
    collect(file);
    function visit(node){
      const fail=message=>errors.push(relative(root,path)+":"+file.getLineAndCharacterOfPosition(node.pos).line+" "+message);
      if(ts.isJsxText(node)&&visibleLiteral(node.text))fail("Hardcoded JSX text: "+node.text.trim());
      if(ts.isJsxAttribute(node)&&/^(title|subtitle|eyebrow|label|detail|placeholder|aria-label|alt)$/.test(node.name.getText(file))&&node.initializer&&ts.isStringLiteral(node.initializer)&&visibleLiteral(node.initializer.text))fail("Hardcoded display attribute: "+node.initializer.text);
      let translationNamespace;
      if(ts.isCallExpression(node)&&ts.isIdentifier(node.expression)){
        let ancestor=node;
        while(ancestor){translationNamespace=bindings.get(scopeOf(ancestor)+":"+node.expression.text);if(translationNamespace)break;ancestor=ancestor.parent;}
      }
      if(translationNamespace){
        const arg=node.arguments[0];
        if(arg&&ts.isStringLiteral(arg)&&get(en,translationNamespace+"."+arg.text)===undefined)fail("Missing translation key: "+translationNamespace+"."+arg.text);
      }
      ts.forEachChild(node,visit);
    }
    visit(file);
    if(/Join the CARD launch pool|Every position\. Fully accounted\.|Global coordination, not a team page\.|Designed to be auditable\.|audited contracts|加入 CARD 发行池|每一笔仓位，完整记账|全球协作，而不只是团队页面|为可审计而生/.test(source))errors.push(path+" contains obsolete copy");
  }
}
await walk(resolve(root,"apps/web/app"));
if(errors.length){console.error(errors.join("\n"));process.exitCode=1;}
else console.log("i18n audit PASS: "+enKeys.length+" paired translations; all app TSX checked.");
