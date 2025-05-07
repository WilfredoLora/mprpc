#!/bin/bash
set -e

echo "🔧 Compiling Cython files in mprpc/ to C (Python 3)..."
cython --language-level=3 mprpc/*.pyx
echo "✅ Done."
