#!/bin/env python3

import os
import sys
import ssl
import socket
import pathlib
import json
import logging
import pprint
from enum import Enum
from optparse import OptionParser
import asyncio
import websockets


pp = pprint.PrettyPrinter(indent=4)

# declare the token variables
fHost = str('')
fPort = int(0)
fUser = str('')
fGridHome = str('')
fPasswd = str('')
fDebug = int(0)
fPID = int(0)
fWSPort = 8097  # websocket port

# other user oriented variables
homedir = os.getenv('HOME', '~')
tmpdir = os.getenv('TMPDIR', '/tmp')
fUser = os.getenv('alien_API_USER', os.getenv('LOGNAME', 'USER'))

j_trusts_dir = homedir + '/.j/trusts/'
j_capath = os.getenv('X509_CERT_DIR', j_trusts_dir)

# let get the token file name
UID = os.getuid()
token_filename = '/tmp/jclient_token_' + str(UID)

# user cert locations
user_globus = homedir + '/.globus'
usercert = user_globus + '/usercert.pem'
userkey = user_globus + '/userkey.pem'

usercertpath = os.getenv('X509_USER_CERT', usercert)
userkeypath = os.getenv('X509_USER_KEY', userkey)

# token certificate
tokencert = '/tmp' + "/tokencert.pem"
tokencertpath = os.getenv('JALIEN_TOKEN_CERT', tokencert)

tokenkey = '/tmp' + "/tokenkey.pem"
tokenkeypath = os.getenv('JALIEN_TOKEN_KEY', tokenkey)

tokenlock = tmpdir + '/jalien_token.lock'

cert = None
key = None

# Web socket static variables
# websocket = None  # global websocket name
# ws_path = '/websocket/json'
ws_path = '/echo'
fHostWS = ''
fHostWSUrl = ''

# Websocket endpoint to be used
# server_central = 'alice-jcentral.cern.ch'
# server_central = '137.138.99.145'
# server_central = 'echo.websocket.org'
server_central = 'demos.kaazing.com'
server_local = '127.0.0.1'
default_server = server_local


def token_parse(token_file):
    global fHost, fPort, fUser, fGridHome, fPasswd, fDebug, fPID, fWSPort
    with open(token_file) as myfile:
        for line in myfile:
            name, var = line.partition("=")[::2]
            if (name == "Host"): fHost = str(var.strip())
            if (name == "Port"): fPort = int(var.strip())
            if (name == "User"): fUser = str(var.strip())
            if (name == "Home"): fGridHome = str(var.strip())
            if (name == "Passwd"): fPasswd = str(var.strip())
            if (name == "Debug"): fDebug = int(var.strip())
            if (name == "PID"): fPID = int(var.strip())
            if (name == "WSPort"): fWSPort = int(var.strip())


def ws_endpoint_detect():
    global fHost, fWSPort, token_filename
    global default_server, server_local, server_central
    global cert, key
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex((server_local, fWSPort))
    if result == 0:
        default_server = server_local
        cert = tokencertpath
        key = tokenkeypath
        token_parse(token_filename)
    else:
        cert = usercertpath
        key = userkeypath
        default_server = server_central
        fHost = default_server
        fPort = 8098
        fWSPort = 8097
        fPasswd = ''


def create_ssl_context():
    global cert, key
    # ssl related options
    ctx = ssl.SSLContext()
    verify_mode = ssl.CERT_REQUIRED  # CERT_NONE, CERT_OPTIONAL, CERT_REQUIRED
    ctx.verify_mode = verify_mode
    ctx.check_hostname = False
    ctx.load_verify_locations(capath='/etc/grid-security/certificates/')
    ctx.load_verify_locations(capath=user_globus)
    alienca = user_globus + '/AliEn-CA.pem'
    ctx.load_verify_locations(cafile=alienca)
    ctx.load_cert_chain(certfile=cert, keyfile=key)
    return ctx


def CreateJsonCommand(command, options=[]):
    cmd_dict = {"command": command, "options": options}
    return json.dumps(cmd_dict)


def ProcessReceivedMessage(message=''):
    print(str(message))


async def Command(cmd, args=[]):
    global websocket, fHostWS, fHostWSUrl, ws_path
    ws_endpoint_detect()
    # fHostWS = 'wss://' + default_server + ':' + str(fWSPort)
    fHostWS = 'ws://' + default_server
    fHostWSUrl = fHostWS + ws_path
    print("Prepare to connect : ", fHostWSUrl)
    if str(fHostWSUrl).startswith("wss://"):
        ssl_context = create_ssl_context()
    else:
        ssl_context = None
    async with websockets.connect(fHostWSUrl, ssl=ssl_context) as websocket:
        json_cmd = CreateJsonCommand(cmd, args)
        # pp.pprint(fHostWSUrl)
        # pp.pprint(json_cmd)
        if ssl_context is not None: ssl.get_ca_certs()
        await websocket.send(json_cmd)
        print(f"Sent> {json_cmd}")
        result = await websocket.recv()
        print("Received< ", result)


if __name__ == '__main__':
    # Let's start the connection
    logger = logging.getLogger('websockets')
    logger.setLevel(logging.INFO)
    logger.addHandler(logging.StreamHandler())

    asyncio.get_event_loop().run_until_complete(Command(cmd='pwd'))




