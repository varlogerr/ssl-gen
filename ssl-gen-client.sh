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

[[ ! -d "${CLIENT_DIR}" ]] && mkdir -p "${CLIENT_DIR}"

file_realpath="$(realpath "${CLIENT_DIR}/${CLIENT_FILENAME}")"
key_file="${file_realpath}.key"
csr_file="${file_realpath}.csr"
ext_file="${file_realpath}.ext"
crt_file="${file_realpath}.crt"

echo "> Generate ${ext_file}"
{
  marker=DNS
  if grep -Pq '^(\d{1,3}\.){3}\d{1,3}$' <<< ${CLIENT_CN}; then
    marker=IP
  fi

  ext_tpl="$(cat "${THE_DIR}/conf/ext.conf")"

  line_num="$(
    grep -Pn '^\s*#\s*\'${marker}'\.1\s*=' <<< "${ext_tpl}" \
    | cut -d: -f1
  )"
  head -n $((line_num - 1)) <<< "${ext_tpl}"
  echo "${marker}.1 = ${CLIENT_CN}"
  tail -n +$((line_num + 1)) <<< "${ext_tpl}"
} > "${ext_file}"

echo "> Generate ${key_file}"
openssl genpkey -algorithm RSA -outform PEM -pkeyopt rsa_keygen_bits:2048 \
  -out "${key_file}"

echo "> Generate ${csr_file}"
openssl req -new -key "${key_file}" \
  -subj "/CN=${CLIENT_CN}" \
  -out "${csr_file}"

echo "> Generate ${crt_file}"
openssl x509 -req -in "${csr_file}" \
  -CA "${CA_DIR}/${CA_PREFIX}ca.crt" \
  -CAkey "${CA_DIR}/${CA_PREFIX}ca.key" \
  -extfile "${ext_file}" \
  -CAcreateserial -days "${CLIENT_DAYS}" -sha256 \
  -passin pass:"${CA_PHRASE}" \
  -out "${crt_file}"
