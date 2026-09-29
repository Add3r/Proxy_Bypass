# Proxy Bypass v1.2.0

## Highlights

- Adds the current 11,170-record user-agent library, including 70 `AI` platform entries.
- Adds `-P ai` support to Python, PowerShell, and Rust.
- Adds standalone PowerShell and Rust clients, with macOS, Linux, and Windows Rust builds.
- Adds Chrome, Microsoft Edge, and Firefox Manifest V3 user-agent header switchers.
- Adds the Burp Suite Montoya User-Agent Fuzzer extension.

## Security and compatibility

- Python/PowerShell use safe curl arguments, reject control characters and non-HTTP(S) targets, ignore curl startup configuration, enforce the selected proxy, and classify final 2xx responses.
- Rust routes both HTTP and HTTPS through the selected proxy, does not follow redirects, and has an updated, advisory-scanned lockfile.
- Burp keeps the captured destination, confirms request replay, offers stopping, and uses strict JSON parsing in a Java 17 build.
- Firefox background-script compatibility, top-level navigation rules and browser save/error handling are corrected.
- Browser extensions change only the outgoing HTTP `User-Agent` header; they do not alter JavaScript-visible identity or User-Agent Client Hints.
- Use all tools only against targets and proxy environments you are authorized to test.

See `SHA256SUMS.txt` in the release assets to verify downloads.

This is a release candidate: live browser/Burp and cross-platform runtime sign-off remains outstanding (see SECURITY_REVIEW.md). Firefox is unsigned; Chrome/Edge use unpacked developer installation. PowerShell requires 7.3+ and curl. GitHub automation creates a draft for review.
