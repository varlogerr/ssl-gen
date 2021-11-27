#!/usr/bin/env bash

THE_SCRIPT="$(basename "${BASH_SOURCE[0]}")"
THE_DIR="$(realpath "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/..")"

cd "${THE_DIR}"
git pull
