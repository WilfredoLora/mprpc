"""
Example RPC server that provides a sum(x, y) method using mprpc and gevent.
"""

from gevent.server import StreamServer
from mprpc import RPCServer


class SumServer(RPCServer):
    def sum(self, x, y):
        return x + y


server = StreamServer(('127.0.0.1', 6000), SumServer())
server.serve_forever()
