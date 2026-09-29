const RULE_ID = 1;
const extension = globalThis.browser ?? globalThis.chrome;
let pending = Promise.resolve();

function validateConfig(config) {
  if (!config || typeof config.enabled !== "boolean" ||
      typeof config.userAgent !== "string" || typeof config.urlFilter !== "string") {
    throw new Error("Invalid configuration.");
  }
  if (config.userAgent.length > 8192 || /[\x00-\x1f\x7f-\uffff]/.test(config.userAgent) ||
      (config.enabled && !config.userAgent)) {
    throw new Error("User-Agent must be a nonempty printable ASCII header (maximum 8192 characters).");
  }
  if (!config.urlFilter.startsWith("|") || config.urlFilter.length > 2048 ||
      /[^\x21-\x7e]/.test(config.urlFilter)) {
    throw new Error("Invalid URL filter.");
  }
  return { enabled: config.enabled, userAgent: config.userAgent, urlFilter: config.urlFilter,
    entryId: typeof config.entryId === "string" ? config.entryId : null };
}

async function applyRule(config) {
  const addRules = [];
  if (config?.enabled) {
    addRules.push({
      id: RULE_ID, priority: 1,
      action: { type: "modifyHeaders",
        requestHeaders: [{ header: "User-Agent", operation: "set", value: config.userAgent }] },
      condition: { urlFilter: config.urlFilter,
        resourceTypes: ["main_frame", "sub_frame", "stylesheet", "script", "image", "font",
          "object", "xmlhttprequest", "ping", "media", "websocket", "other"] }
    });
  }
  await extension.declarativeNetRequest.updateDynamicRules({ removeRuleIds: [RULE_ID], addRules });
}

async function saveConfig(raw) {
  const config = validateConfig(raw);
  await applyRule(config);
  try {
    await extension.storage.local.set({ config });
  } catch (error) {
    // Fail closed if persistence fails: don't leave an unrecorded override enabled.
    await applyRule(null);
    throw error;
  }
  return { ok: true };
}

extension.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type !== "save-config" || sender.id !== extension.runtime.id) return false;
  pending = pending.then(() => saveConfig(message.config));
  pending.then(sendResponse, (error) => sendResponse({ ok: false, error: error.message }));
  pending = pending.catch(() => {});
  return true;
});

extension.runtime.onInstalled.addListener(() => {
  pending = pending.then(async () => {
    const { config } = await extension.storage.local.get("config");
    await applyRule(config ? validateConfig(config) : null);
  }).catch(async () => { await applyRule(null); });
});
