# Burp Suite User-Agent Fuzzer

`UserAgentFuzzer.jar` is a Java/Montoya extension that sweeps a captured Burp request with entries from the bundled 11,170-record library, including the `AI` platform and `AI-Agents` group.

1. In Burp, open **Extensions** and add `UserAgentFuzzer.jar` as a Java extension.
2. In Proxy, Repeater, Logger, or another request view, right-click a request and choose **Send to User-Agent Fuzzer tab**.
3. In the **User-Agent Fuzzer** tab, verify the read-only captured destination, choose platform, browser groups and batching settings, then select **Start sweep** and confirm the replay.
4. Review status-code results and optionally save the complete sweep log.

The extension retains the original request method, body, headers, and destination, changing only `User-Agent`. It never automatically retargets a captured request. Repeated requests can change server state, especially POST/PUT/DELETE requests. Use only authorized requests and avoid production transactions. **Stop after current request** stops subsequent sends; an in-flight Burp request may still finish.

The bundled JSON is the only automatically loaded library; files in Burp's working directory are ignored. Replace this directory's JSON and rebuild to update it. Gson performs strict JSON parsing, and invalid headers fail closed.

## Build from source

From the repository root, with a Java 17+ JDK and Python 3:

```bash
python3 scripts/build_burp.py
```

Pinned dependencies: Montoya API 2025.10 (compile-only; supplied by Burp at runtime) and Gson 2.14.0 (bundled under Apache-2.0, see GSON-LICENSE). The builder verifies dependency checksums and targets Java 17; use a Burp version compatible with the 2025.10 API. Live Burp UI/request testing remains a release sign-off step.
