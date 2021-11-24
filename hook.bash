export SSL_GEN_SCRIPTS_DIR="${SSL_GEN_SCRIPTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if !  tr ':' '\n' <<< "${PATH}" | sort | uniq \
      | grep -Fxq "${SSL_GEN_SCRIPTS_DIR}"; then
  # ${SSL_GEN_SCRIPTS_DIR} is not in the ${PATH}
  export PATH="${SSL_GEN_SCRIPTS_DIR}:${PATH}"
fi
