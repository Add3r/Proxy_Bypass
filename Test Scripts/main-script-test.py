import subprocess
import time
import signal

commands = [
    'python3 new-exfil.py -h'
    'python3 new-exfil.py -l',
    # Option -s examples
    'python3 new-exfil.py -s "ua-3918","ua-3917","ua-3916"',
    'python3 new-exfil.py -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com',
    'python3 new-exfil.py -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -v -s "ua-3918","ua-3917","ua-3916"',
    'python3 new-exfil.py -v -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com',
    'python3 new-exfil.py -v -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -s "ua-3918","ua-3917","ua-3916" -r 1 -t 10',
    'python3 new-exfil.py -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com -r 1 -t 10',
    'python3 new-exfil.py -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com -p 127.0.0.1:443 -r 1 -t 10',
    'python3 new-exfil.py -v -s "ua-3918","ua-3917","ua-3916" -r 1 -t 10',
    'python3 new-exfil.py -v -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com -r 1 -t 10',
    'python3 new-exfil.py -v -s "ua-3918","ua-3917","ua-3916" -T www.facebook.com -p 127.0.0.1:443 -r 1 -t 10',
    # Option -ua examples
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0sdfjsdfjsahdfjsad"',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0sdfjsdfjsahdfjsad" -T www.facebook.com',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0sdfjsdfjsahdfjsad" -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0"',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0" -T www.facebook.com',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0" -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0sdfjsdfjsahdfjsad" -r 1 -t 20',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0sdfjsdfjsahdfjsad" -T www.facebook.com -r 1 -t 20',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0sdfjsdfjsahdfjsad" -T www.facebook.com -p 127.0.0.1:443 -r 1 -t 20',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0" -r 1 -t 20',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0" -T www.facebook.com -r 1 -t 20',
    'python3 new-exfil.py -ua "Mozilla/5.0 (Macintosh; U; i386 Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Hana/1.0" -T www.facebook.com -p 127.0.0.1:443 -r 1 -t 20',
    #Default usage examples
    'python3 new-exfil.py',
    'python3 new-exfil.py -v',
    'python3 new-exfil.py -v -r 1 -t 10',
    'python3 new-exfil.py -T www.facebook.com',
    'python3 new-exfil.py -v -T www.facebook.com',
    'python3 new-exfil.py -v -T www.facebook.com -r 1 -t 10',
    'python3 new-exfil.py -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -v -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -v -T www.facebook.com -p 127.0.0.1:443 -r 1 -t 10',
    'python3 new-exfil.py -p 127.0.0.1:443',
    'python3 new-exfil.py -v -p 127.0.0.1:443',
    'python3 new-exfil.py -v -p 127.0.0.1:443 -r 1 -t 10',
    # Option -B examples
    'python3 new-exfil.py -B Firefox',
    'python3 new-exfil.py -B Firefox Hana',
    'python3 new-exfil.py -B Firefox Hana -T www.facebook.com',
    'python3 new-exfil.py -B Firefox Hana -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -v -B Firefox',
    'python3 new-exfil.py -v -B Firefox Hana',
    'python3 new-exfil.py -v -B Firefox Hana -T www.facebook.com',
    'python3 new-exfil.py -v -B Firefox Hana -T www.facebook.com -p 127.0.0.1:443',
    'python3 new-exfil.py -B Firefox -r 2 -t 5',
    'python3 new-exfil.py -B Firefox Hana -r 2 -t 5',
    'python3 new-exfil.py -B Firefox Hana -T www.facebook.com -r 2 -t 5',
    'python3 new-exfil.py -B Firefox Hana -T www.facebook.com -p 127.0.0.1:443 -r 2 -t 5',
    'python3 new-exfil.py -v -B Firefox -r 2 -t 5',
    'python3 new-exfil.py -v -B Firefox Hana -r 2 -t 5',
    'python3 new-exfil.py -v -B Firefox Hana -T www.facebook.com -r 2 -t 5',
    'python3 new-exfil.py -v -B Firefox Hana -T www.facebook.com -p 127.0.0.1:443 -r 2 -t 5',
    'python3 new-exfil.py -B Firefox -p 127.0.0.1:443',
    'python3 new-exfil.py -B Firefox Hana -p 127.0.0.1:443',
    'python3 new-exfil.py -v -B Firefox -p 127.0.0.1:443',
    'python3 new-exfil.py -v -B Firefox Hana -p 127.0.0.1:443',
    # Option -P examples
    'python3 new-exfil.py -P general',
    'python3 new-exfil.py -P mobile',
    'python3 new-exfil.py -P all',
    'python3 new-exfil.py -v -P general',
    'python3 new-exfil.py -v -P mobile',
    'python3 new-exfil.py -v -P all',
    'python3 new-exfil.py -P general -r 2 -t 5',
    'python3 new-exfil.py -v -P general -r 2 -t 5',
    'python3 new-exfil.py -P general -T www.facebook.com',
    'python3 new-exfil.py -P mobile -T www.facebook.com',
    'python3 new-exfil.py -P all -T www.facebook.com',
    'python3 new-exfil.py -v -P general -T www.facebook.com',
    'python3 new-exfil.py -v -P mobile -T www.facebook.com',
    'python3 new-exfil.py -v -P all -T www.facebook.com',
    'python3 new-exfil.py -P general -r 2 -t 5 -T www.facebook.com',
    'python3 new-exfil.py -v -P general -r 2 -t 5 -T www.facebook.com',
    'python3 new-exfil.py -P general -p 127.0.0.1:443',
    'python3 new-exfil.py -P mobile -p 127.0.0.1:443',
    'python3 new-exfil.py -P all -p 127.0.0.1:443',
    'python3 new-exfil.py -v -P general -p 127.0.0.1:443',
    'python3 new-exfil.py -v -P mobile -p 127.0.0.1:443',
    'python3 new-exfil.py -v -P all -p 127.0.0.1:443',
    'python3 new-exfil.py -P general -r 2 -t 5 -p 127.0.0.1:443',
    'python3 new-exfil.py -v -P general -r 2 -t 5 -p 127.0.0.1:443',
    'python3 new-exfil.py -P general -p 127.0.0.1:443 -T www.facebook.com',
    'python3 new-exfil.py -P mobile -p 127.0.0.1:443 -T www.facebook.com',
    'python3 new-exfil.py -P all -p 127.0.0.1:443 -T www.facebook.com',
    'python3 new-exfil.py -v -P general -p 127.0.0.1:443 -T www.facebook.com',
    'python3 new-exfil.py -v -P mobile -p 127.0.0.1:443 -T www.facebook.com',
    'python3 new-exfil.py -v -P all -p 127.0.0.1:443 -T www.facebook.com',
    'python3 new-exfil.py -P general -r 2 -t 5 -p 127.0.0.1:443 -T www.facebook.com',
    'python3 new-exfil.py -v -P general -r 2 -t 5 -p 127.0.0.1:443 -T www.facebook.com',
]

for cmd in commands:
    print(f"\nExecuting: {cmd}\n" + "="*50)
    
    # If the command is using -B or -P, set a timeout
    timeout = 50 if ("-B" in cmd or "-P" in cmd) else None
    
    process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_IGN))
    
    try:
        output, error = process.communicate(timeout=timeout)
        print(output.decode('utf-8'))
    except subprocess.TimeoutExpired:
        # If a timeout occurs (i.e., for -B or -P commands), send a Ctrl+C signal
        print("\nSending Ctrl+C signal to interrupt the command...")
        process.send_signal(signal.SIGINT)
        output, error = process.communicate()
        print(output.decode('utf-8'))

print("\nAll commands executed!")
