class RPCProtocolError(Exception):
    """Raised when there is a protocol error in the RPC communication."""
    pass

class MethodNotFoundError(Exception):
    """Raised when the requested RPC method is not found."""
    pass

class RPCError(Exception):
    """Raised for general RPC-related errors."""
    pass
