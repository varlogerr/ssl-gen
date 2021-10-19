#!/usr/bin/env bash

THE_SCRIPT="$(basename "${BASH_SOURCE[0]}")"
THE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${THE_DIR}/lib/opter.sh"
. "${THE_DIR}/vars/gen-client.sh"
export THE_DESCRIPTION="${GEN_CLIENT_DESCRIPTION}"
export THE_USAGE="${GEN_CLIENT_USAGE}"
export THE_OPTS="${GEN_CLIENT_OPTS}"
export THE_DEMO="${GEN_CLIENT_DEMO}"

opter_parse_input "${@}"

optfiles="$(while read -r optfile; do
  [[ -z "${optfile}" ]] && continue
  echo "${OPTER_PARSED_OPTS[${optfile}]}"
done <<< "$(
  sed 's/ /\n/g' <<< "${!OPTER_PARSED_OPTS[@]}" \
  | grep -P '^optfile\.\d+' \
  | sort -V | tac
)")"

IFS_KEEP="${IFS}"; IFS=$'\n'
for f in ${optfiles}; do
  IFS="${IFS_KEEP}"
  [[ -z "${f}" ]] && continue
  opter_parse_optfile "${f}"
done

# apply defaults
for o in "${!OPTER_OPTS_PATTERN[@]}"; do
  if [[ -z "${OPTER_PARSED_OPTS[${o}]}" ]] \
  && [[ -n "${OPTER_OPTS_DEFAULT[${o}]}" ]]; then
    OPTER_PARSED_OPTS[${o}]="${OPTER_OPTS_DEFAULT[${o}]}"
  fi
done

CA_DIR="${OPTER_PARSED_OPTS[ca-dir]}"
CA_PHRASE="${OPTER_PARSED_OPTS[ca-phrase]}"
CA_PREFIX="${OPTER_PARSED_OPTS[ca-file-prefix]}"
CLIENT_DAYS="${OPTER_PARSED_OPTS[client-cert-days]}"
CLIENT_CN="${OPTER_PARSED_OPTS[client-cn]}"
CLIENT_DIR="${OPTER_PARSED_OPTS[client-dir]}"
FORCE="${OPTER_PARSED_OPTS[force]}"
SILENT="${OPTER_PARSED_OPTS[silent]}"

# validate --force and --silent flags
if [[ ${FORCE} -eq 1 ]] && [[ ${FORCE} == ${SILENT} ]]; then
  echo "--force and --silent are not allowed together"
  exit
fi

while [[ -z "${CLIENT_CN}" ]]; do
  read -p 'Client CN (for example *.site.local): ' CLIENT_CN
  [[ -z "${CLIENT_CN}" ]] && echo "Can't be blank"
done

CLIENT_FILENAME="${OPTER_PARSED_OPTS[client-filename]:-$(sed 's/\*/_/' <<< "${CLIENT_CN}")}"

# check existing cert files
{
  existing_files="$(while read -r f; do
    [[ -z "${f}" ]] && continue
    [[ -f "${f}" ]] && echo "${f}"
  done <<< "
${CLIENT_DIR}/${CLIENT_FILENAME}.key
${CLIENT_DIR}/${CLIENT_FILENAME}.ext
${CLIENT_DIR}/${CLIENT_FILENAME}.csr
${CLIENT_DIR}/${CLIENT_FILENAME}.crt
  ")"

  if [[ -n "${existing_files}" ]] && [[ ${FORCE} -ne 1 ]]; then
    echo "The following files already exist:"
    while read -r f; do
      echo "* ${f}"
    done <<< "${existing_files}"

    if [[ ${SILENT} -eq 1 ]]; then
      echo "Exiting"    
      exit
    fi

    while :; do
      read -p 'Override existing files? (y/N) ' override
      [[ -z "${override}" ]] && override=N

      if [[ "${override}" =~ ^[Yy]$ ]]; then
        break
      fi
      if [[ "${override}" =~ ^[Nn]$ ]]; then
        exit
      fi

      override=''
    done
  fi
}

unreadable="$(
  for f in  "${CA_DIR}/${CA_PREFIX}ca.crt" \
            "${CA_DIR}/${CA_PREFIX}ca.key" \
  ; do
    [[ -z "${f}" ]] && continue
    [[ ! -r "${f}" ]] && echo "${f}"
  done
)"

if [[ -n "${unreadable}" ]]; then
  echo "The following files can't be accessed:"
  while read -r f; do echo "* ${f}"; done <<< "${unreadable}"
  echo "Make sure they exist and readable!"
  exit 1
fi

if [[ -z "${CA_PHRASE}" ]]; then
  read -sp 'CA Phrase: ' CA_PHRASE
  echo
fi

[[ ! -d "${CLIENT_DIR}" ]] && mkdir -p "${CLIENT_DIR}"

while ! openssl rsa -passin pass:"${CA_PHRASE}" \
      -in "${CA_DIR}/${CA_PREFIX}ca.key" > /dev/null 2>&1; do
  echo "Invalid CA Phrase!"
  read -sp 'CA Phrase: ' CA_PHRASE
  echo
done

for v in  CA_DIR \
          CA_PHRASE \
          CA_PREFIX \
          CLIENT_DAYS \
          CLIENT_CN \
          CLIENT_DIR \
          CLIENT_FILENAME \
          FORCE \
          SILENT \
; do
  val="${!v}"
  if [[ "${v}" == CA_PHRASE ]]; then
    val="$(sed 's/./\*/g' <<< "${!v}")"
  fi
  echo "${v} = ${val}"
done

echo "> Generate ${CLIENT_DIR}/${CLIENT_FILENAME}.key"
openssl genpkey -algorithm RSA -outform PEM -pkeyopt rsa_keygen_bits:2048 \
  -out "${CLIENT_DIR}/${CLIENT_FILENAME}.key"

echo "> Generate ${CLIENT_DIR}/${CLIENT_FILENAME}.csr"
openssl req -new -key "${CLIENT_DIR}/${CLIENT_FILENAME}.key" \
  -subj "/CN=${CLIENT_CN}" \
  -out "${CLIENT_DIR}/${CLIENT_FILENAME}.csr"

echo "> Generate ${CLIENT_DIR}/${CLIENT_FILENAME}.ext"
while read -r l; do
  [[ -n "${l}" ]] && echo "${l}"
done <<< "
  authorityKeyIdentifier=keyid,issuer
  basicConstraints=CA:FALSE
  keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
  extendedKeyUsage = serverAuth
  subjectAltName = @alt_names
  [alt_names]
  DNS.1 = ${CLIENT_CN}
  # DNS.2 = www.domain.local
  # IP.1 = 192.168.0.55
" > "${CLIENT_DIR}/${CLIENT_FILENAME}.ext"

echo "> Generate ${CLIENT_DIR}/${CLIENT_FILENAME}.crt"
openssl x509 -req -in "${CLIENT_DIR}/${CLIENT_FILENAME}.csr" \
  -CA "${CA_DIR}/${CA_PREFIX}ca.crt" \
  -CAkey "${CA_DIR}/${CA_PREFIX}ca.key" \
  -extfile "${CLIENT_DIR}/${CLIENT_FILENAME}.ext" \
  -CAcreateserial -days "${CLIENT_DAYS}" -sha256 \
  -passin pass:"${CA_PHRASE}" \
  -out "${CLIENT_DIR}/${CLIENT_FILENAME}.crt"
