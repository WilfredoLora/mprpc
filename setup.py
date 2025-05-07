# -*- coding: utf-8 -*-

from setuptools import setup
from Cython.Build import cythonize

with open("README.rst", encoding="utf-8") as f:
    long_description = f.read()

with open("LICENSE", encoding="utf-8") as f:
    license_text = f.read()

setup(
    name='mprpc',
    version='0.1.18',
    description='A fast MessagePack RPC library',
    long_description=long_description,
    author='Studio Ousia',
    author_email='ikuya@ousia.jp',
    url='http://github.com/studio-ousia/mprpc',
    packages=['mprpc'],
    ext_modules=cythonize([
        'mprpc/client.pyx',
        'mprpc/server.pyx'
    ]),
    license=license_text,
    include_package_data=True,
    keywords=['rpc', 'msgpack', 'messagepack', 'msgpackrpc', 'messagepackrpc',
              'messagepack rpc', 'gevent'],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: Apache Software License',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Programming Language :: Python :: 3.12',
    ],
    install_requires=[
        'gsocketpool',
        'gevent',
        'msgpack',
    ],
    tests_require=[
        'nose',
        'mock',
    ],
    test_suite='nose.collector'
)
