import time
import multiprocessing

NUM_CALLS = 10000


def run_sum_server():
    from gevent.server import StreamServer
    from mprpc import RPCServer

    class SumServer(RPCServer):
        def sum(self, x, y):
            return x + y

    server = StreamServer(('127.0.0.1', 6000), SumServer())
    server.serve_forever()


def call():
    from mprpc import RPCClient

    client = RPCClient('127.0.0.1', 6000)

    start = time.time()
    [client.call('sum', 1, 2) for _ in range(NUM_CALLS)]

    print(f'call: {NUM_CALLS / (time.time() - start):.2f} qps')


def call_using_connection_pool():
    from mprpc import RPCPoolClient

    import gevent.pool
    import gsocketpool.pool

    def _call(n):
        with client_pool.connection() as client:
            return client.call('sum', 1, 2)

    options = dict(host='127.0.0.1', port=6000)
    client_pool = gsocketpool.pool.Pool(RPCPoolClient, options, initial_connections=20)
    glet_pool = gevent.pool.Pool(20)

    start = time.time()

    [None for _ in glet_pool.imap_unordered(_call, range(NUM_CALLS))]

    print(f'call_using_connection_pool: {NUM_CALLS / (time.time() - start):.2f} qps')


if __name__ == '__main__':
    p = multiprocessing.Process(target=run_sum_server)
    p.start()

    time.sleep(1)

    call()
    call_using_connection_pool()

    p.terminate()
