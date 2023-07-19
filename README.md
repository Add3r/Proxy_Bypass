# Proxy_Bypass
Admin repo for the Proxy_Bypass


##### Lab Setup for Dev and Testing #####

# Windows - Intel

# MacOSx - M1/Intel
1. download and install docker(choose specific chipset)
2. Container choosen - https://hub.docker.com/r/datadog/squid
3. run docker container with following command
"docker run --name squid -d -p 127.0.0.1:8080:3128 -v <fullpath>/logs/squid:/var/log/squid -v <fullpath>/config/squid.conf:/etc/squid/squid.conf datadog/squid"
4. Configure proxy settings to check if traffic is going through Squid container. Note: proxy ports for your squid container may differ as per mods in step 3 command.
Browser or Foxy Proxy settings - add new proxy as squid container
(or)
recommended - to change system level network settings to go through squid proxy
5. Check if squid proxy config has following lines

acl bad_browser browser ^Mozilla 
http_access deny bad_browser all

now any mozilla/firefox browser or useragent traffic should be blocked or denied access.
Smale output:
TCP_DENIED/403 4147 GET http://example.com/ - HIER_NONE/- text/html

