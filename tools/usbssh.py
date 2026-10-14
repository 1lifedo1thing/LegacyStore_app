#!/usr/bin/env python3
import os, plistlib, select, socket, struct, sys

def send(s, d, tag):
    p = plistlib.dumps(d)
    s.sendall(struct.pack('<IIII', 16 + len(p), 1, 8, tag) + p)

def recv(s):
    ln = struct.unpack('<IIII', s.recv(16))[0]
    b = b''
    while len(b) < ln - 16:
        b += s.recv(ln - 16 - len(b))
    return plistlib.loads(b)

def mux():
    s = socket.socket(socket.AF_UNIX)
    s.connect('/var/run/usbmuxd')
    return s

base = {'ClientVersionString': 'usbssh', 'ProgName': 'usbssh'}
port = int(sys.argv[1]) if len(sys.argv) > 1 else 22

s = mux()
send(s, {**base, 'MessageType': 'ListDevices'}, 1)
devs = [d for d in recv(s)['DeviceList'] if d['Properties'].get('ConnectionType') == 'USB']
s.close()
if not devs:
    sys.exit('usbssh: geen iOS-apparaat via USB gevonden')

s = mux()
send(s, {**base, 'MessageType': 'Connect', 'DeviceID': devs[0]['DeviceID'], 'PortNumber': socket.htons(port)}, 2)
if recv(s).get('Number') != 0:
    sys.exit(f'usbssh: apparaat weigert poort {port}')

fin, fout = sys.stdin.fileno(), sys.stdout.fileno()
while True:
    r, _, _ = select.select([s, fin], [], [])
    if s in r:
        data = s.recv(65536)
        if not data:
            break
        os.write(fout, data)
    if fin in r:
        data = os.read(fin, 65536)
        if not data:
            break
        s.sendall(data)
