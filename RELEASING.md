# Releasing v1.2.0

The local release is a candidate pending the manual host-application and destination-OS checks in SECURITY_REVIEW.md. No upload or public release is implied by local packaging.

## Rebuild and verify

Run from the repository root with Python 3, Node, PowerShell 7.3+, curl, a Java 17+ JDK, Rust and the required cross-compilers:

```sh
python3 scripts/check_libraries.py
python3 -m unittest discover -s tests -p 'test_*.py'
node tests/browser-security.cjs
pwsh -NoProfile -File tests/powershell-security.ps1
cargo test --locked --manifest-path Rust/Cargo.toml
cargo clippy --locked --manifest-path Rust/Cargo.toml -- -D warnings
(cd Rust && cargo audit)
bash Rust/build_targets.sh
python3 scripts/build_burp.py
javac --release 17 -cp Burp-extension/UserAgentFuzzer.jar:Burp-extension/montoya-api-2025.10.jar tests/BurpLibraryTest.java
java -cp tests:Burp-extension/UserAgentFuzzer.jar:Burp-extension/montoya-api-2025.10.jar BurpLibraryTest
python3 scripts/release_integrity.py verify all
bash scripts/package_release.sh v1.2.0 release
(cd release && shasum -a 256 -c SHA256SUMS.txt)
```

The output directory must be empty. Preserve older candidates in a separate directory.
The Rust build script has Homebrew cross-toolchain defaults; override its CC/AR variables for other build hosts. It stops if any target fails. Native-only source builds use `cargo build --locked --release --manifest-path Rust/Cargo.toml`.

## GitHub

Review and commit the source, Cargo.lock, dependencies, built Rust binaries, Burp JAR and both build-manifest.json files together. Do not include caches, old class files or local release directories. After sign-off, tag the reviewed commit v1.2.0 and push it. The pinned-checkout workflow validates the tagged tree, runs tests/advisory checks, packages it, and creates a **draft** GitHub release. Review its assets/checksums before publishing.

Manual dispatch requires an existing tag and always checks out that tag. Firefox permanent installation additionally requires Mozilla signing; Chrome/Edge packages are unpacked developer extensions.
