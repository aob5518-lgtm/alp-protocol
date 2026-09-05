import {defineConfig} from "@playwright/test";
export default defineConfig({
  testDir:"./test/e2e",
  timeout:60000,
  expect:{timeout:10000},
  workers:2,
  reporter:[["list"],["html",{open:"never"}]],
  use:{baseURL:"http://127.0.0.1:3100",trace:"retain-on-failure",screenshot:"only-on-failure"},
  webServer:{command:"node node_modules/next/dist/bin/next start -p 3100",url:"http://127.0.0.1:3100",reuseExistingServer:!process.env.CI,timeout:120000},
  projects:[
    {name:"desktop",use:{viewport:{width:1440,height:900}}},
    {name:"wide",use:{viewport:{width:1920,height:1080}}},
    {name:"tablet",use:{viewport:{width:768,height:1024}}},
    {name:"mobile430",use:{viewport:{width:430,height:932}}},
    {name:"mobile390",use:{viewport:{width:390,height:844}}},
    {name:"mobile375",use:{viewport:{width:375,height:812}}},
  ],
});
