import {test,expect} from "@playwright/test";
import en from "../../messages/en-US.json";
import zh from "../../messages/zh-CN.json";
const routeKeys=[
  ["/","explore"],["/app/explore","explore"],["/app/assets/relique","assetRelique"],
  ["/app/launch/relique","launch"],["/app/portfolio","portfolio"],["/app/network","network"],
  ["/app/protocol","protocol"],["/app/top100","top100"],["/app/nodes","nodes"],
] as const;
const flattened=(obj:object):string[]=>Object.values(obj).flatMap(v=>typeof v==="string"?[v]:flattened(v));
for(const locale of ["en-US","zh-CN"] as const){
  test(locale+" all pages, metadata and translated body",async({page,context},info)=>{
    const dictionary=locale==="zh-CN"?zh:en,other=locale==="zh-CN"?en:zh;
    await context.addCookies([{name:"alp.locale",value:locale,url:"http://127.0.0.1:3100"}]);
    const failures:string[]=[];page.on("pageerror",error=>failures.push(error.message));
    for(const [route,key] of routeKeys){
      const response=await page.goto(route);
      expect(response?.status()).toBe(200);
      await expect(page.locator("h1")).toHaveText(dictionary[key].title);
      await expect(page.locator("html")).toHaveAttribute("lang",locale);
      await expect(page).toHaveTitle(dictionary.common.metadataTitle);
      await expect(page.locator('meta[name="description"]')).toHaveAttribute("content",dictionary.common.metadataDescription);
      const trigger=page.locator(".locale-trigger").first();
      await expect(trigger).toBeVisible();
      const box=await trigger.boundingBox();expect(box!.x).toBeGreaterThanOrEqual(0);expect(box!.x+box!.width).toBeLessThanOrEqual(page.viewportSize()!.width);
      expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBeTruthy();
      const body=await page.locator("body").innerText();
      const current=new Set(flattened(dictionary));
      for(const foreign of flattened(other).filter(v=>v.length>12&&!current.has(v)&&!v.includes("{"))){
        expect(body,route+" must not show "+foreign).not.toContain(foreign);
      }
      if(route.startsWith("/app/"))await expect(page.locator(".app-sidebar a[href='/admin']")).toHaveCount(0);
      if(route==="/app/launch/relique")for(const text of [dictionary.launch.participation,dictionary.launch.allocation,dictionary.launch.time])await expect(page.getByText(text,{exact:true})).toBeVisible();
      await page.screenshot({path:info.outputPath(locale+"-"+(route==="/"?"landing":route.replaceAll("/","-"))+".png"),fullPage:true});
    }
    expect(failures).toEqual([]);
  });
}
test("landing anchors, language switching and persistence",async({page,context})=>{
  await page.goto("/");
  await expect(page.locator("h1")).toHaveText(en.explore.title);
  await page.getByRole("button",{name:en.common.language,exact:true}).click();
  await page.getByRole("menuitemradio",{name:"简体中文"}).click();
  await expect(page.locator("h1")).toHaveText(zh.explore.title);
  for(const key of ["assets","protocol","ecosystem","developers","docs"] as const){
    await page.locator("header nav").getByRole("link",{name:zh.landing[key],exact:true}).click();
    await expect(page).toHaveURL(new RegExp("#"+key+"$"));
    await expect.poll(()=>page.locator("#"+key).evaluate(el=>Math.abs(el.getBoundingClientRect().top))).toBeLessThan(100);
  }
  await page.locator("header .top-actions").getByRole("link",{name:zh.landing.launchApp,exact:true}).click();
  await expect(page.locator("h1")).toHaveText(zh.explore.title);
  const nav=page.viewportSize()!.width<=760?page.locator(".app-mobile-nav"):page.locator(".app-sidebar");
  await nav.getByRole("link",{name:zh.nav.launch,exact:true}).click();
  await expect(page.locator("h1")).toHaveText(zh.launch.title);
  await nav.getByRole("link",{name:zh.nav.portfolio,exact:true}).click();
  await expect(page.locator("h1")).toHaveText(zh.portfolio.title);
  await page.reload();await expect(page.locator("h1")).toHaveText(zh.portfolio.title);
  expect(await page.evaluate(()=>localStorage.getItem("alp.locale"))).toBe("zh-CN");
  expect((await context.cookies()).find(c=>c.name==="alp.locale")?.value).toBe("zh-CN");
  const reopened=await context.newPage();await page.close();
  await reopened.goto("/app/explore");await expect(reopened.locator("h1")).toHaveText(zh.explore.title);
  await reopened.getByRole("button",{name:zh.common.language,exact:true}).click();
  await reopened.getByRole("menuitemradio",{name:"English"}).click();
  await expect(reopened.locator("h1")).toHaveText(en.explore.title);
  await reopened.reload();await expect(reopened.locator("h1")).toHaveText(en.explore.title);
  await reopened.getByRole("button",{name:en.wallet.connect,exact:true}).click();
  const dialog=reopened.getByRole("dialog");await expect(dialog).toBeVisible();
  await expect(dialog).toContainText(en.wallet.connectWallet);
});
test("cookie renders Chinese before JavaScript; localStorage cannot override it",async({browser})=>{
  const context=await browser.newContext({javaScriptEnabled:false});
  await context.addCookies([{name:"alp.locale",value:"zh-CN",url:"http://127.0.0.1:3100"}]);
  const page=await context.newPage();await page.goto("/app/explore");
  await expect(page.locator("h1")).toHaveText(zh.explore.title);
  await expect(page.locator("html")).toHaveAttribute("lang","zh-CN");
  await context.close();
  const hydrated=await browser.newContext();
  await hydrated.addCookies([{name:"alp.locale",value:"zh-CN",url:"http://127.0.0.1:3100"}]);
  const hydratedPage=await hydrated.newPage();
  await hydratedPage.addInitScript(()=>localStorage.setItem("alp.locale","en-US"));
  await hydratedPage.goto("/app/explore");
  await expect(hydratedPage.locator("h1")).toHaveText(zh.explore.title);
  await expect(hydratedPage.locator("html")).toHaveAttribute("lang","zh-CN");
  expect(await hydratedPage.evaluate(()=>localStorage.getItem("alp.locale"))).toBe("zh-CN");
  await hydrated.close();
});
