## Write a code for testing proxy configuration with only 2 useragents, one that is allowed in proxy and one that is not allowed in proxy

# allowed user agent being Mozilla/5.0 (Linux; U; Android 4.0.3; ko-kr; LG-L160L Build/IML74K) AppleWebkit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30
# disallowed user agent being Mozilla/5.0 (Linux; U; Android 4.0.3; de-ch; HTC Sensation Build/IML74K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30
# 2 request for each, one that reaches out to an HTTP server and one that reachers out to an HTTPS server (www.google.com)

import requests

allowed_ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:99.0) Gecko/20100101 Firefox/99.0"
disallowed_ua = "Mozilla/5.0 (Linux; U; Android 4.0.3; de-ch; HTC Sensation Build/IML74K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"

http_urls = ["http://www.columbia.edu/~fdc/sample.html"]
# https_urls = ["https://www.google.com"]

proxies = {
    "http": "http://127.0.0.1:8080"
}

# Test allowed user agent with HTTP requests
for url in http_urls:
    try:
        response = requests.get(url, headers={"User-Agent": allowed_ua}, proxies=proxies)
        response.raise_for_status()
        print(f"[+] {allowed_ua} successful for {url}")
    except requests.exceptions.HTTPError:
        print(f"[!] {allowed_ua} error for {url}")

# Test disallowed user agent with HTTP requests
for url in http_urls:
    try:
        response = requests.get(url, headers={"User-Agent": disallowed_ua}, proxies=proxies)
        response.raise_for_status()
        print(f"[+] {disallowed_ua} successful for {url}")
    except requests.exceptions.HTTPError:
        print(f"[!] {disallowed_ua} error for {url}")