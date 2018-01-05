#!/usr/bin/env python
"""A simple HTTPS server in Python.

If arguments are provided on the command line, the first argument is considered
to be the port to use and the second is a file containing both the server's
private key and certificate in PEM format. If these arguments are not provided,
a random port is used with server.pem from the current working directory.

"""
import BaseHTTPServer, SimpleHTTPServer
import ssl
import sys

port = int(sys.argv[1]) if sys.argv[1:] else 0
certfile = sys.argv[2] if sys.argv[2:] else './server.pem'

server = BaseHTTPServer.HTTPServer(('localhost', port), SimpleHTTPServer.SimpleHTTPRequestHandler)
server.socket = ssl.wrap_socket(server.socket, certfile=certfile, server_side=True)

print "Serving HTTPS on {0} port {1} ...".format(*server.server_address)
sys.stdout.flush()

server.serve_forever()
