#!/usr/bin/env bash

THE_SCRIPT="$(basename "${BASH_SOURCE[0]}")"
THE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${THE_DIR}/lib/opter.sh"
. "${THE_DIR}/vars/gen-ca.sh"
export THE_DESCRIPTION="${GEN_CA_DESCRIPTION}"
export THE_USAGE="${GEN_CA_USAGE}"
export THE_OPTS="${GEN_CA_OPTS}"
export THE_DEMO="${GEN_CA_DEMO}"

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

CA_DAYS="${OPTER_PARSED_OPTS[ca-cert-days]}"
CA_CN="${OPTER_PARSED_OPTS[ca-cn]}"
CA_DIR="${OPTER_PARSED_OPTS[ca-dir]}"
CA_PHRASE="${OPTER_PARSED_OPTS[ca-phrase]}"
CA_PREFIX="${OPTER_PARSED_OPTS[ca-file-prefix]}"
FORCE="${OPTER_PARSED_OPTS[force]}"
SILENT="${OPTER_PARSED_OPTS[silent]}"

# validate --force and --silent flags
if [[ ${FORCE} -eq 1 ]] && [[ ${FORCE} == ${SILENT} ]]; then
  echo "--force and --silent are not allowed together"
  exit
fi

# check existing cert files
{
  existing_files="$(while read -r f; do
    [[ -z "${f}" ]] && continue
    [[ -f "${f}" ]] && echo "${f}"
  done <<< "
${CA_DIR}/${CA_PREFIX}ca.key
${CA_DIR}/${CA_PREFIX}ca.crt
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

# ensure common name
while [[ -z "${CA_CN}" ]]; do
  read -p 'CA CN (for example Acme): ' CA_CN
  echo
  [[ -z "${CA_CN}" ]] && echo "Can't be blank"
done

# ensure phrase
err_msg=
while :; do
  if [[ -z "${err_msg}" ]]; then
    if [[ -z "${CA_PHRASE}" ]]; then
      err_msg="Phrase is blank!"
    elif !  openssl genpkey -algorithm RSA -aes256 \
            -outform PEM -pkeyopt rsa_keygen_bits:4096 \
            -pass pass:"${CA_PHRASE}" > /dev/null 2>&1 \
    ; then
      err_msg="Phrase is incorrect!"
    fi
  fi

  [[ -z "${err_msg}" ]] && break

  echo "${err_msg}"
  read -sp 'Phrase: ' CA_PHRASE
  echo
  if [[ -z "${CA_PHRASE}" ]]; then
    err_msg="Phrase is blank!"
    continue
  fi
  read -sp 'Confirm phrase: ' confirm_ca_phrase
  echo

  if [[ "${CA_PHRASE}" == "${confirm_ca_phrase}" ]]; then
    err_msg=
    continue
  fi
  err_msg="Phrase doesn't match confirm"
done

for v in  CA_DAYS \
          CA_DIR \
          CA_CN \
          CA_PHRASE \
          CA_PREFIX \
          FORCE \
          SILENT \
; do
  val="${!v}"
  if [[ "${v}" == CA_PHRASE ]]; then
    val="$(sed 's/./\*/g' <<< "${!v}")"
  fi
  echo "${v} = ${val}"
done

[[ ! -d "${CA_DIR}" ]] && mkdir -p "${CA_DIR}"

echo "> Generate ${CA_PREFIX}ca.key"
openssl genpkey -algorithm RSA -aes256 -outform PEM -pkeyopt rsa_keygen_bits:4096 \
  -pass pass:"${CA_PHRASE}" \
  -out "${CA_DIR}/${CA_PREFIX}ca.key"

echo "> Generate ${CA_PREFIX}ca.crt"
openssl req -x509 -new -nodes -sha512 -days "${CA_DAYS}" \
  -key "${CA_DIR}/${CA_PREFIX}ca.key" \
  -passin pass:"${CA_PHRASE}" \
  -subj "/O=${CA_CN} Org/OU=${CA_CN} Unit/CN=${CA_CN}" \
  -out "${CA_DIR}/${CA_PREFIX}ca.crt"
