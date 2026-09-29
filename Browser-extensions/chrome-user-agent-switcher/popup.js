const $ = (id) => document.getElementById(id);
const extension = globalThis.browser ?? globalThis.chrome;
let library = [];
let selectedEntry = null;

function option(select, value, label) {
  const item = document.createElement("option");
  item.value = value;
  item.textContent = label;
  select.append(item);
}

function selectedPlatform() { return $("platform").value; }
function selectedGroup() { return $("group").value; }

function refillGroups() {
  const old = selectedGroup();
  $("group").replaceChildren();
  option($("group"), "all", "All groups");
  [...new Set(library.filter((entry) => selectedPlatform() === "all" || entry.platform.toLowerCase() === selectedPlatform())
    .map((entry) => entry.group))].sort().forEach((group) => option($("group"), group, group));
  $("group").value = [...$("group").options].some((item) => item.value === old) ? old : "all";
  refillEntries();
}

function refillEntries() {
  const query = $("search").value.trim().toLowerCase();
  const platform = selectedPlatform();
  const group = selectedGroup();
  const matches = library.filter((entry) =>
    (platform === "all" || entry.platform.toLowerCase() === platform) &&
    (group === "all" || entry.group === group) &&
    (!query || [entry.id, entry.title, entry.group, entry["user-agent"]].join(" ").toLowerCase().includes(query))
  );
  const preserved = matches.find((entry) => entry.id === selectedEntry?.id);
  matches.splice(250);
  if (preserved && !matches.includes(preserved)) matches.push(preserved);
  $("entry").replaceChildren();
  matches.forEach((entry) => option($("entry"), entry.id, `${entry.id} — ${entry.title} (${entry.group})`));
  if (selectedEntry && matches.some((entry) => entry.id === selectedEntry.id)) $("entry").value = selectedEntry.id;
  chooseEntry();
}

function chooseEntry() {
  selectedEntry = library.find((entry) => entry.id === $("entry").value) || null;
  $("selected").textContent = selectedEntry ? selectedEntry["user-agent"] : "No library entry selected.";
}

async function save() {
  const userAgent = $("custom").value.trim() || selectedEntry?.["user-agent"];
  const urlFilter = $("url-filter").value.trim() || "|http";
  if ($("enabled").checked && !userAgent) return setStatus("Choose an entry or enter a custom user-agent.", true);
  if (!urlFilter.startsWith("|")) return setStatus("URL filter must start with | (for example |https://example.com/).", true);
  const config = { enabled: $("enabled").checked, userAgent: userAgent || "", urlFilter, entryId: $("custom").value.trim() ? null : selectedEntry?.id || null };
  try {
    const reply = await extension.runtime.sendMessage({ type: "save-config", config });
    if (!reply?.ok) throw new Error(reply?.error || "No confirmation from background script.");
    setStatus(config.enabled ? "Header override is active." : "Header override is disabled.");
  } catch (error) { setStatus(`Could not apply rule: ${error.message}`, true); }
}

function setStatus(message, error = false) {
  $("status").textContent = message;
  $("status").style.color = error ? "#b00020" : "#087f23";
}

async function init() {
  library = await fetch(extension.runtime.getURL("user_agents.json")).then((response) => response.json());
  option($("platform"), "all", "All platforms");
  [...new Set(library.map((entry) => entry.platform))].sort().forEach((platform) => option($("platform"), platform.toLowerCase(), platform));
  const { config } = await extension.storage.local.get("config");
  if (config) {
    $("enabled").checked = Boolean(config.enabled);
    $("url-filter").value = config.urlFilter || "|http";
    selectedEntry = library.find((entry) => entry.id === config.entryId) || null;
    if (!selectedEntry && config.userAgent) $("custom").value = config.userAgent;
    if (selectedEntry) $("platform").value = selectedEntry.platform.toLowerCase();
  }
  refillGroups();
  if (selectedEntry) $("group").value = selectedEntry.group;
  refillEntries();
  $("platform").addEventListener("change", refillGroups);
  $("group").addEventListener("change", refillEntries);
  $("search").addEventListener("input", refillEntries);
  $("entry").addEventListener("change", chooseEntry);
  $("save").addEventListener("click", save);
  setStatus(`${library.length.toLocaleString()} entries loaded.`);
}

init().catch((error) => setStatus(`Library load failed: ${error.message}`, true));
