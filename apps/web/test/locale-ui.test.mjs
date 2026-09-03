import assert from "node:assert/strict";
import test from "node:test";
import {readFile} from "node:fs/promises";

const read = (file) => readFile(new URL(`../${file}`, import.meta.url), "utf8");

test("mobile locale trigger remains visible and opens a language sheet", async () => {
  const [page, css, en, zh] = await Promise.all([
    read("app/page.tsx"),
    read("app/locale.css"),
    read("messages/en-US.json"),
    read("messages/zh-CN.json"),
  ]);

  assert.match(page, /className="locale-trigger"/);
  assert.doesNotMatch(page, /className="control"/);
  assert.match(page, /<span>English<\/span>/);
  assert.match(page, /<span>简体中文<\/span>/);
  assert.match(css, /\.locale-trigger\s*\{[\s\S]*display: flex !important/);
  assert.match(css, /\.locale-menu\s*\{[\s\S]*position: fixed/);
  assert.match(en, /"language":"Language"/);
  assert.match(zh, /"language":"语言"/);
});

test("locale selection persists in both browser stores", async () => {
  const providers = await read("app/providers.tsx");
  assert.match(providers, /localStorage\.getItem\("alp\.locale"\)/);
  assert.match(providers, /localStorage\.setItem\("alp\.locale", locale\)/);
  assert.match(providers, /document\.cookie = `alp\.locale=\$\{locale\}/);
});
