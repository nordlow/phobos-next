#!/bin/bash

set -euo pipefail

if [[ ! -f /usr/lib/x86_64-linux-gnu/libtcc.a ]]; then
	package_list="libtcc-dev"
	echo "Installing missing APT packages: $package_list ..."
	sudo apt install $package_list
fi
