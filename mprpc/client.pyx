# cython: language_level=3
# cython: profile=False
# -*- coding: utf-8 -*-

import msgpack
import time
from gevent import socket
from gsocketpool.connection import Connection

from mprpc.exceptions import RPCProtocolError, RPCError
from mprpc.constants import MSGPACKRPC_REQUEST, MSGPACKRPC_RESPONSE, SOCKET_RECV_SIZE

from mprpc import logger


cdef class RPCClient:
    """RPC client.

    Usage:
        >>> from mprpc import RPCClient
        >>> client = RPCClient('127.0.0.1', 6000)
        >>> print(client.call('sum', 1, 2))
        3

    :param str host: Hostname.
    :param int port: Port number.
    :param int timeout: (optional) Socket timeout.
    :param bool lazy: (optional) If set to True, the socket connection is not
        established until you specifically call open()
    :param str pack_encoding: (optional) Ignored in Python 3. Use pack_params instead.
    :param str unpack_encoding: (optional) Ignored in Python 3. Use unpack_params instead.
    :param dict pack_params: (optional) Parameters to pass to MessagePack Packer.
    :param dict unpack_params: (optional) Parameters to pass to MessagePack Unpacker.
    :param tcp_no_delay: (optional) If set to True, use TCP_NODELAY.
    :param keep_alive: (optional) If set to True, enable socket keep-alive.
    """

    cdef str _host
    cdef int _port
    cdef int _msg_id
    cdef _timeout
    cdef _socket
    cdef _packer
    cdef _pack_params
    cdef _unpack_params
    cdef _tcp_no_delay
    cdef _keep_alive

    def __init__(self, host, port, timeout=None, lazy=False,
                 pack_encoding='utf-8', unpack_encoding='utf-8',
                 pack_params=None, unpack_params=None,
                 tcp_no_delay=False, keep_alive=False):

        self._host = host
        self._port = port
        self._timeout = timeout
        self._msg_id = 0
        self._socket = None
        self._tcp_no_delay = tcp_no_delay
        self._keep_alive = keep_alive

        self._pack_params = pack_params or dict(use_bin_type=True)
        self._unpack_params = unpack_params or dict(raw=False, use_list=False)

        self._packer = msgpack.Packer(**self._pack_params)

        if not lazy:
            self.open()

    def getpeername(self):
        """Return the address of the remote endpoint."""
        return self._host, self._port

    def open(self):
        """Opens a connection."""
        assert self._socket is None, 'The connection has already been established'
        logger.debug('Opening a msgpackrpc connection')

        if self._timeout:
            self._socket = socket.create_connection((self._host, self._port), self._timeout)
        else:
            self._socket = socket.create_connection((self._host, self._port))

        if self._tcp_no_delay:
            self._socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

        if self._keep_alive:
            self._socket.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)

    def close(self):
        """Closes the connection."""
        assert self._socket is not None, 'Attempt to close an unopened socket'

        logger.debug('Closing a msgpackrpc connection')
        try:
            self._socket.close()
        except Exception:
            logger.exception('An error has occurred while closing the socket')

        self._socket = None

    def is_connected(self):
        """Returns whether the connection has already been established."""
        return self._socket is not None

    def call(self, method, *args):
        """Calls an RPC method.

        :param method: Method name (str or unicode).
        :param args: Arguments to pass.
        """
        cdef bytes req = self._create_request(method, args)
        cdef bytes data

        self._socket.sendall(req)

        unpacker = msgpack.Unpacker(**self._unpack_params)

        while True:
            data = self._socket.recv(SOCKET_RECV_SIZE)
            if not data:
                raise IOError('Connection closed')

            unpacker.feed(data)
            try:
                response = next(unpacker)
                break
            except StopIteration:
                continue

        if not isinstance(response, (tuple, list)):
            logger.debug(f'Protocol error, received unexpected data: {data}')
            raise RPCProtocolError('Invalid protocol')

        return self._parse_response(response)

    cdef bytes _create_request(self, method, args):
        self._msg_id += 1
        cdef tuple req = (MSGPACKRPC_REQUEST, self._msg_id, method, args)
        return self._packer.pack(req)

    cdef _parse_response(self, response):
        if len(response) != 4 or response[0] != MSGPACKRPC_RESPONSE:
            raise RPCProtocolError('Invalid protocol')

        cdef int msg_id
        (_, msg_id, error, result) = response

        if msg_id != self._msg_id:
            raise RPCError('Invalid Message ID')

        if error:
            raise RPCError(str(error))

        return result


class RPCPoolClient(RPCClient, Connection):
    """RPC client integrated with `gsocketpool`.

    Usage:
        >>> import gsocketpool.pool
        >>> from mprpc import RPCPoolClient
        >>> client_pool = gsocketpool.pool.Pool(RPCPoolClient, dict(host='127.0.0.1', port=6000))
        >>> with client_pool.connection() as client:
        ...     print(client.call('sum', 1, 2))
        3
    """

    def __init__(self, host, port, timeout=None, lifetime=None,
                 pack_encoding='utf-8', unpack_encoding='utf-8',
                 pack_params=None, unpack_params=None,
                 tcp_no_delay=False, keep_alive=False):

        if lifetime:
            assert lifetime > 0, 'Lifetime must be a positive value'
            self._lifetime = time.time() + lifetime
        else:
            self._lifetime = None

        super().__init__(
            host, port, timeout=timeout, lazy=True,
            pack_encoding=pack_encoding, unpack_encoding=unpack_encoding,
            pack_params=pack_params or {}, unpack_params=unpack_params or {},
            tcp_no_delay=tcp_no_delay, keep_alive=keep_alive
        )

    def is_expired(self):
        """Returns whether the connection has expired."""
        return not self._lifetime or time.time() > self._lifetime

    def call(self, method, *args):
        """Calls an RPC method."""
        try:
            return super().call(method, *args)
        except socket.timeout:
            self.reconnect()
            raise
        except IOError:
            self.reconnect()
            raise
