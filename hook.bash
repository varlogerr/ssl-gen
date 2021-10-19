export SSL_GEN_DIR="${SSL_GEN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if \
    ! grep -qFo "${SSL_GEN_DIR}:" <<< "${PATH}" \
    && ! grep -qFo ":${SSL_GEN_DIR}" <<< "${PATH}" \
; then
  export PATH="${PATH:+${PATH}:}${SSL_GEN_DIR}"
fi
