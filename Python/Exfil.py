#!/bin/python3
import os
from urllib.request import urlopen
import re
from html.parser import HTMLParser

class HTML_Href_Parser(HTMLParser):

    def handle_starttag(self, tag, attrs):
        # Only parse the 'anchor' tag.
        if tag == "a":
           # Check the list of defined attributes.
           for name, value, data in attrs:
                #print(title)
               # If href is defined, print it.
                if name == "href":
                    #def handle_data(self, data):
                    print(data)

parser = HTML_Href_Parser()

class MyHTMLParser(HTMLParser):

    def handle_data(self, data):
        #for x in data.isalnum():
        print(data)

parser2 = MyHTMLParser()

print("Useragent Exfil quick test script")
#parser.feed("http://www.useragentstring.com/pages/useragentstring.php?name=All")
# dump Array of useragents from source

url="http://www.useragentstring.com/pages/useragentstring.php?name=All"
page=urlopen(url)
html_bytes=page.read()
html=html_bytes.decode("utf-8",errors="ignore")
print(html)
parser2.feed(html)







# Array of user agents to test
#UserAgents=[
#    'Chrome/5.0 (Macintosh; Intel Mac OS X 10.15; rv:101.0) Gecko/20100101 Firefox/101.0', #HTTP/1.1 200 OK
#    'Mozilla/5.0 (Windows; NT 6.0; rv:101.0) Gecko/20100101 Firefox/101.0' #HTTP/1.1 403 Forbidden
#]

# iterate through each user agent and test for access 
#for x in UserAgents:
#    result=os.popen('curl --user-agent "{}" http://www.example.com -I --proxy "http://127.0.0.1:8080"'.format(x)).read()
#    print(result)


