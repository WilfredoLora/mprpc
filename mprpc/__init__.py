# -*- coding: utf-8 -*-

import logging
from logging import NullHandler

from mprpc.client import RPCClient, RPCPoolClient
from mprpc.server import RPCServer

logger = logging.getLogger(__name__)
logger.addHandler(NullHandler())

__all__ = ["RPCClient", "RPCPoolClient", "RPCServer"]
