#!/bin/bash

set -euo pipefail

# Some extra install steps after nix setup.
# Can be done for a clean install. May also need to be executed after moving directories (.venv links get messed up)
# May need to clear .venv first (rm, and then allow nix venv shell hook to reapply)

# Install bril2txt and bril2json
pip install flit
cd bril/bril-txt
flit install --symlink
