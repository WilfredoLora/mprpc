# -*- coding: utf-8 -*-
"""
Constants used by the mprpc package.
"""

MSGPACKRPC_REQUEST: int = 0
MSGPACKRPC_RESPONSE: int = 1

# Max size for receiving socket data (1 MiB)
SOCKET_RECV_SIZE: int = 1024 ** 2
