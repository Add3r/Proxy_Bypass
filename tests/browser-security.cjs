const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

async function test(browser) {
  let listener, rules, stored, failRules = false, failStorage = false;
  const api = {
    runtime: { id: "test-extension", onMessage: { addListener(fn) { listener = fn; } },
      onInstalled: { addListener() {} } },
    storage: { local: {
      async get() { return { config: stored }; },
      async set({ config }) { if (failStorage) throw new Error("Storage failure"); stored = config; }
    } },
    declarativeNetRequest: { async updateDynamicRules(value) {
      if (failRules) throw new Error("Rule failure");
      rules = value;
    } }
  };
  vm.runInNewContext(fs.readFileSync(`Browser-extensions/${browser}-user-agent-switcher/service-worker.js`, "utf8"),
    { chrome: api });
  const save = config => new Promise(resolve => {
    assert.equal(listener({ type: "save-config", config }, { id: api.runtime.id }, resolve), true);
  });
  const config = { enabled: true, userAgent: "Test UA", urlFilter: "|https://example.test/" };
  assert.equal((await save(config)).ok, true);
  assert.ok(rules.addRules[0].condition.resourceTypes.includes("main_frame"));
  const old = stored;
  assert.equal((await save({ ...config, userAgent: "UA\r\nInjected: yes" })).ok, false);
  assert.equal(stored, old);
  failRules = true;
  assert.equal((await save({ ...config, userAgent: "New" })).ok, false);
  assert.equal(stored, old);
  failRules = false; failStorage = true;
  assert.equal((await save({ ...config, userAgent: "New" })).ok, false);
  assert.equal(rules.addRules.length, 0);
  failStorage = false;
  assert.equal((await save({ ...config, enabled: false })).ok, true);
  assert.equal(rules.addRules.length, 0);
  assert.equal(listener({ type: "save-config", config }, { id: "foreign" }, () => {}), false);
  const manifest = JSON.parse(fs.readFileSync(`Browser-extensions/${browser}-user-agent-switcher/manifest.json`));
  assert.deepEqual(manifest.host_permissions, ["http://*/*", "https://*/*"]);
  if (browser === "firefox") assert.deepEqual(manifest.background, { scripts: ["service-worker.js"] });
  console.log(`${browser}: message validation, navigation rules, failure handling and permissions passed`);
}
Promise.all(["chrome", "firefox"].map(test)).catch(error => { console.error(error); process.exitCode = 1; });
