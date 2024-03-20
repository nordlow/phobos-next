#!/bin/bash

set -euo pipefail

# TODO: Replace this with a `ci.d`

echo '### Build "phobos-next" ...'
dub --root=. build

echo '### Test "phobos-next" ...'
dub --root=. test

echo '### Build and run test application "test/containers" ...'
dub --root=test/containers run

echo '### Build and run test application "test/gc-benchmark" ...'
pushd test/gc-benchmark
./test.sh
popd

echo '### Build and run test application "test/allocators-benchmark" ...'
dub --root=test/allocators-benchmark run --build=release

echo '### Build and run test application "test/class-memuse" ...'
dub --root=test/class-memuse run --build=release

echo '### Build test application "test/lispy-benchmark" ...'
dub --root=test/lispy-benchmark build

echo '### Build test application "test/lpgen" ...'
# TODO: enable when compiles with -dip1000 and linker issues have been fixed
# dub --root=test/lpgen build

echo '### Build library "tcc-d2" ...'
dub --root=tcc-d2 build

echo '### Build library "xdag" ...'
# TODO: enable: dub --root=xdag build

echo '### Build library "zio" ...'
dub --root=zio build
