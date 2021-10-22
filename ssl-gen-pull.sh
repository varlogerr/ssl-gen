#!/usr/bin/env bash

THE_DIR="$(realpath "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"

cd "${THE_DIR}"
git pull
