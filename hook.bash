export SSL_GEN_BINDIR="${SSL_GEN_BINDIR:-$(dirname "$(realpath "${BASH_SOURCE[0]}")")/bin}"
export SSL_GEN_PREPEND_PATH="${SSL_GEN_PREPEND_PATH:-0}"

if \
  !  tr ':' '\n' <<< "${PATH}" | sort | uniq \
  | grep -Fxq "${SSL_GEN_BINDIR}" \
; then
  # ${SSL_GEN_BINDIR} is not in the ${PATH}

  if [[ ${SSL_GEN_PREPEND_PATH} == 1 ]]; then
    # prepend ssl-gen bin path to $PATH
    export PATH="${SSL_GEN_BINDIR}${PATH:+:${PATH}}"
  else
    # append ssl-gen bin path to $PATH
    export PATH="${PATH:+${PATH}:}${SSL_GEN_BINDIR}"
  fi
fi
