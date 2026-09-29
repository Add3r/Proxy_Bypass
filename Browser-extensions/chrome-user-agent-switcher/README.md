# Chrome and Microsoft Edge user-agent switcher

1. Open `chrome://extensions`, enable **Developer mode**, and choose **Load unpacked**.
2. Select this directory.
3. Open the extension popup, choose a library entry (or provide a custom string), set a narrow URL filter, enable it, and save.

The extension uses Manifest V3 declarative network rules to replace the outgoing `User-Agent` request header. It does not alter `navigator.userAgent` or User-Agent Client Hints. Use it only on systems and targets you are authorized to test.

For Microsoft Edge, follow the same steps at `edge://extensions`; no separate extension is required.
The default filter covers all HTTP(S) sites when enabled: narrow it before saving. Protected browser pages cannot be modified. This is an unpacked developer distribution, not a signed store installation.
