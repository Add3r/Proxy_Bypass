# Firefox user-agent switcher

1. In Firefox 128+, open `about:debugging#/runtime/this-firefox` and choose **Load Temporary Add-on**.
2. Select this directory's manifest.json (or the release XPI).
3. Open the extension popup, choose a library entry (or provide a custom string), set a narrow URL filter, enable it, and save.

The extension uses Manifest V3 declarative network rules to replace the outgoing `User-Agent` request header. It does not alter `navigator.userAgent` or User-Agent Client Hints. Use it only on systems and targets you are authorized to test.

The XPI is unsigned; permanent installation requires Mozilla signing. Grant the requested HTTP/HTTPS host permissions. The default filter covers all HTTP(S) sites when enabled: narrow it before saving. Protected browser pages cannot be modified.
