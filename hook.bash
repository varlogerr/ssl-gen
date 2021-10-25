export SSL_GEN_DIR="${SSL_GEN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

export PATH="$(
  if tr ':' '\n' <<< "${PATH}" | grep -Fx "${SSL_GEN_DIR}"; then
    # ${SSL_GEN_DIR} is in the ${PATH}
    echo "${PATH}"
  else
    echo "${SSL_GEN_DIR}:${PATH}"
  fi
)"
