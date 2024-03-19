#!/usr/bin/env bash

set -euo pipefail

exec dub test --compiler=dmd
