docker run --name squid -d -p 8080:3128 -v ./logs/squid:/var/log/squid -v ./config/squid.conf:/etc/squid/squid.conf datadog/squid # path modification needed with absolute path specification of working directory

# powershell
docker run --name squid -d -p 8080:3128 -v $pwd/logs/squid:/var/log/squid -v $pwd/config/squid.conf:/etc/squid/squid.conf datadog/squid

# MacOS-12 M1
docker run --name squid -d -p 127.0.0.1:8080:3128 -v <file-path>/logs/squid:/var/log/squid -v <file-path>/config/squid.conf:/etc/squid/squid.conf datadog/squid

# Localhost IP address was given for 
# --platform linux/arm64/v8 :  
#WARNING: image with reference datadog/squid was found but does not match the specified platform: wanted linux/arm64/v8, actual: linux/amd64
#docker: Error response from daemon: image with reference datadog/squid was found but does not match the specified platform: wanted linux/arm64/v8, actual: linux/amd64.
