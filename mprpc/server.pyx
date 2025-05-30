# cython: language_level=3
# cython: profile=False
# -*- coding: utf-8 -*-

import gevent.socket
import msgpack

from mprpc.constants import MSGPACKRPC_REQUEST, MSGPACKRPC_RESPONSE, SOCKET_RECV_SIZE
from mprpc.exceptions import MethodNotFoundError, RPCProtocolError
from gevent.local import local


cdef class RPCServer:
    """RPC server.

    This class is assumed to be used with gevent StreamServer.

    :param dict pack_params: (optional) Parameters to pass to MessagePack Packer.
    :param dict unpack_params: (optional) Parameters to pass to MessagePack Unpacker.

    Usage:
        >>> from gevent.server import StreamServer
        >>> import mprpc
        >>>
        >>> class SumServer(mprpc.RPCServer):
        ...     def sum(self, x, y):
        ...         return x + y
        ...
        >>> server = StreamServer(('127.0.0.1', 6000), SumServer())
        >>> server.serve_forever()
    """

    cdef _packer
    cdef _unpack_params
    cdef _tcp_no_delay
    cdef _methods
    cdef _address

    def __init__(self, *args, **kwargs):
        pack_params = kwargs.pop('pack_params', dict(use_bin_type=True))
        self._unpack_params = kwargs.pop('unpack_params', dict(raw=False, use_list=False))

        self._tcp_no_delay = kwargs.pop('tcp_no_delay', False)
        self._methods = {}

        self._packer = msgpack.Packer(**pack_params)

        self._address = local()
        self._address.client_host = None
        self._address.client_port = None

        if args and isinstance(args[0], gevent.socket.socket):
            self._run(_RPCConnection(args[0]))

    def __call__(self, sock, address):
        if self._tcp_no_delay:
            sock.setsockopt(gevent.socket.IPPROTO_TCP, gevent.socket.TCP_NODELAY, 1)

        self._address.client_host = address[0]
        self._address.client_port = address[1]

        self._run(_RPCConnection(sock))

    @property
    def client_host(self):
        """Return the client host."""
        return self._address.client_host

    @property
    def client_port(self):
        """Return the client port."""
        return self._address.client_port

    def _run(self, _RPCConnection conn):
        cdef bytes data
        cdef int msg_id

        unpacker = msgpack.Unpacker(**self._unpack_params)

        while True:
            data = conn.recv(SOCKET_RECV_SIZE)
            if not data:
                break

            unpacker.feed(data)
            try:
                req = next(unpacker)
            except StopIteration:
                continue

            if not isinstance(req, (tuple, list)):
                self._send_error("Invalid protocol", -1, conn)
                unpacker = msgpack.Unpacker(**self._unpack_params)
                continue

            (msg_id, method, args) = self._parse_request(req)

            try:
                ret = method(*args)
            except Exception as e:
                self._send_error(str(e), msg_id, conn)
            else:
                self._send_result(ret, msg_id, conn)

    cdef tuple _parse_request(self, req):
        if len(req) != 4 or req[0] != MSGPACKRPC_REQUEST:
            raise RPCProtocolError('Invalid protocol')

        cdef int msg_id

        (_, msg_id, method_name, args) = req

        method = self._methods.get(method_name, None)

        if method is None:
            if method_name.startswith('_'):
                raise MethodNotFoundError(f'Method not found: {method_name}')

            if not hasattr(self, method_name):
                raise MethodNotFoundError(f'Method not found: {method_name}')

            method = getattr(self, method_name)
            if not callable(method):
                raise MethodNotFoundError(f'Method is not callable: {method_name}')

            self._methods[method_name] = method

        return (msg_id, method, args)

    cdef _send_result(self, object result, int msg_id, _RPCConnection conn):
        msg = (MSGPACKRPC_RESPONSE, msg_id, None, result)
        conn.send(self._packer.pack(msg))

    cdef _send_error(self, str error, int msg_id, _RPCConnection conn):
        msg = (MSGPACKRPC_RESPONSE, msg_id, error, None)
        conn.send(self._packer.pack(msg))


cdef class _RPCConnection:
    cdef _socket

    def __init__(self, socket):
        self._socket = socket

    cdef recv(self, int buf_size):
        return self._socket.recv(buf_size)

    cdef send(self, bytes msg):
        self._socket.sendall(msg)

    def __del__(self):
        try:
            self._socket.close()
        except Exception:
            pass
