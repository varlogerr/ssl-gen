export SSL_GEN_BINDIR="${SSL_GEN_BINDIR:-$(dirname "$(realpath "${BASH_SOURCE[0]}")")/bin}"

if !  tr ':' '\n' <<< "${PATH}" | sort | uniq \
      | grep -Fxq "${SSL_GEN_BINDIR}"; then
  # ${SSL_GEN_BINDIR} is not in the ${PATH}
  export PATH="${SSL_GEN_BINDIR}:${PATH}"
fi
