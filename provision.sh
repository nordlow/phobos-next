#!/bin/bash
set -euo pipefail

sudo apt install $(grep -Po 'packages: \K.*' .github/workflows/d.yml)
# llvm-symbolizer is needed for correct ASan diagnostics
# llvm-symbolizer --version
