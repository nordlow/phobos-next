#!/bin/bash

# Segregated GC
echo
echo "=============="
echo "Segregated GC:"
dub run --build=release-nobounds-segregated-gc

# Conservative GC
echo
echo "================"
echo "Conservative GC:"
dub run --build=release-nobounds -- --DRT-gcopt=gc:conservative
echo

# Precise GC with four-way-parallel marking
echo
echo "==========="
echo "Precise GC:"
dub run --build=release-nobounds -- --DRT-gcopt=gc:precise
