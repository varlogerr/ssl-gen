#!/usr/bin/env bash

THE_SCRIPT="$(basename "${BASH_SOURCE[0]}")"
THE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${THE_DIR}/lib/opter.sh"
. "${THE_DIR}/vars/gen-optfile.sh"
export THE_DESCRIPTION="${GEN_OPTFILE_DESCRIPTION}"
export THE_USAGE="${GEN_OPTFILE_USAGE}"
export THE_DEMO="${GEN_OPTFILE_DEMO}"

opter_parse_input "${@}"

INIT_OPTFILE="${OPTER_PARSED_ARGS[0]}"

INIT_OPTS="$(
  if [[ -n "${INIT_OPTFILE}" ]] && [[ -f "${INIT_OPTFILE}" ]]; then
    cat "${INIT_OPTFILE}"
  fi
)"

declare -A type_map=(
  [ca]=GEN_CA_OPTS
  [client]=GEN_CLIENT_OPTS
)

GEN_OPTFILE_OPTIONS_COLLECTOR="$(
  for type in "${!type_map[@]}"; do
    . "${THE_DIR}/vars/gen-${type}.sh"

    opts_varname="${type_map[${type}]}"
    echo "${!opts_varname}"
  done
)"

if [[ -n "${INIT_OPTFILE}" ]]; then
  mkdir -p "$(dirname "${INIT_OPTFILE}")"
fi

(
  echo '##########'
  while IFS= read -r l; do
    if [[ -n "$(sed 's/ //g' <<< "${l}")" ]]; then
      printf '%s %s\n' '#' "${l:4}"
    fi
  done <<< "
    * each line in the file to be in OPT=VAL format
    * lines starting with # and blank lines are
      ignored
    * blank lines are ignored
    * quotation marks are part of the VAL
    * inline options override the ones from the
      option file
    * there is no expansion for values from option
      files, i.e. ~ or \$(pwd) won't be processed
      as the home directory or current working
      directory
    * for flag options 0 or empty string to disable
      the flag and 1 to enable it
  "
  echo '##########'
  echo

  # $1 - space separated exclude list
  # $2 - initial optfile content
  # $3 - options to create optfile
  opter_gen_optfile 'optfile' "${INIT_OPTS}" "${GEN_OPTFILE_OPTIONS_COLLECTOR}"
) > "${INIT_OPTFILE:-/dev/stdout}"