# v1.2.0 security review

Review date: 2026-09-26. This is a source review and targeted regression pass, not a penetration-test certification or guarantee of no vulnerabilities.

## Corrections

- Python/PowerShell invoke curl without a shell, reject header control characters and non-HTTP(S) targets, disable curl startup configuration and URL globbing, and pass targets as explicit option values. They override NO_PROXY so requests use the tester-selected proxy, bound request time, and classify only the final successful 2xx status.
- Rust now proxies both HTTP and HTTPS, disables redirects, verifies TLS, and uses its embedded library by default instead of silently trusting a working-directory JSON file. Explicit custom files remain supported.
- Burp no longer defaults captured requests to a different host. Destination remains the captured service, replay requires confirmation, and a stop control prevents later requests. The bundled library is parsed strictly with Gson, not regular expressions; working-directory JSON is not loaded. Montoya stubs are excluded from the JAR.
- Firefox uses background scripts, not an unsupported service-worker manifest. Browser rules include top-level navigation. Save messages validate headers/filter values, serialize updates, report errors, and disable overrides if storage fails. Permissions are limited to HTTP(S); the UI uses textContent rather than HTML insertion.
- Rust lockfile dependencies were updated. cargo audit completed with no reported findings across 154 dependencies and 1,271 loaded advisories. This is the Rust dependency result, not a claim about every installed runtime or the host curl/Burp/browser.
- Release packaging uses allowlisted files, validates source/artifact hashes, includes licenses, and generates SHA-256 checksums. GitHub automation checks out an existing exact tag and creates a draft, not an automatically public release.

## Verification

- Python unit tests cover shell/option injection, header controls, unsupported URL schemes, curl failure handling, and final status classification.
- A loopback proxy integration test checks real Python and PowerShell curl execution, quoted headers, and routing despite NO_PROXY=*.
- Rust tests verify HTTP forwarding, HTTPS CONNECT routing, redirect behavior, target validation and embedded AI entries. Clippy passes with warnings denied.
- Node tests mock extension APIs to exercise sender/config validation, top-level navigation rules, removal, and rule/storage failure handling.
- Java 17 compilation and a Montoya-interface test load all 11,170 JSON records, including 70 AI entries, from the built JAR.
- All six distributed JSON files are byte-identical and schema/header validated. Five Rust targets were rebuilt; native macOS ARM64 execution is checked.

## Remaining release sign-off

- Live Chrome, Edge, Firefox and Burp GUI/request tests have not been completed. API mocks and compilation cannot prove full host-app compatibility.
- Linux, Windows and Intel macOS artifacts are cross-built, not runtime-tested on those destination systems. Linux builds depend on a compatible system C runtime. PowerShell requires 7.3+ and curl; Windows PowerShell 5.1 is not supported.
- Firefox XPI is unsigned. Browser-store signing, OS code signing/notarization and a remote GitHub Actions run have not been performed.
- Burp replays original credentials and bodies to the original service: use only authorized, disposable requests. Stopping does not undo completed requests or abort an in-flight send.
- CLI legacy default target remains www.google.com; explicitly set -T to an authorized target. Browser overrides default to all HTTP(S) sites when enabled; narrow the URL filter before saving. A 2xx response is not proof of an access-control bypass.
- Build manifests and checksums detect local staleness/corruption; they are not signed supply-chain attestations. Dependency advisories may change after this review.
