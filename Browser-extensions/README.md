# Browser extensions

Each directory is a separate unpacked Manifest V3 extension containing the same canonical `user_agents.json` library (11,170 records, including the 70-entry `AI` platform).

- `chrome-user-agent-switcher/`: load unpacked from `chrome://extensions` with Developer mode enabled, or unpack `ProxyBypass-UserAgent-Switcher-Chrome.zip`.
- Microsoft Edge uses the same Chrome package, loaded unpacked from `edge://extensions`; no separate build is needed.
- `firefox-user-agent-switcher/`: load temporarily from `about:debugging#/runtime/this-firefox` using its `manifest.json`, or use `ProxyBypass-UserAgent-Switcher-Firefox.xpi` for temporary installation. Permanent Firefox installation requires signing through Mozilla's normal add-on process.

The popup applies one selected or custom value using a declarative rule and defaults to all HTTP(S) requests. Narrow the URL filter before enabling it—for example, `|https://test.example/`. It changes only the outgoing HTTP `User-Agent` header. It intentionally does not spoof JavaScript-visible browser identity or User-Agent Client Hints. Use only in an authorized testing scope.
