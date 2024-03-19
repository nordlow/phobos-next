#!/bin/bash
set -euo pipefail

dub test --build=unittest-previews
dub test
