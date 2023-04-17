#!/bin/python3
import os
print("Useragent Exfil quick test script")

# Array of user agents to test
Top5UA=[
    'Chrome/5.0 (Macintosh; Intel Mac OS X 10.15; rv:101.0) Gecko/20100101 Firefox/101.0', #HTTP/1.1 200 OK
    'Mozilla/5.0 (Windows; NT 6.0; rv:101.0) Gecko/20100101 Firefox/101.0' #HTTP/1.1 403 Forbidden
]

# iterate through each user agent and test for access 
for x in Top5UA:
    result=os.popen('curl --user-agent "{}" http://www.example.com -I --proxy "http://127.0.0.1:8080"'.format(x)).read()
    print(result)


