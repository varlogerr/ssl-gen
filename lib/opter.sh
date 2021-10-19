# ([<numeric-position>]=<flag-name>)
declare -A __OPTER_POS_TO_OPT=()
# ([<flag-name>]=<pattern>)
declare -A OPTER_OPTS_PATTERN=()
# ([<flag-name>]=<help>)
declare -A OPTER_OPTS_HELP=()
# ([<flag-name>]=<example>)
declare -A OPTER_OPTS_EXAMPLE=()
# ([<flag-name>]=<default>)
declare -A OPTER_OPTS_DEFAULT=()
# ([<flag-name>]=<is-required-bool>)
declare -A OPTER_OPTS_IS_REQUIRED=()
# ([<flag-name>]=<is-flag-bool>)
declare -A OPTER_OPTS_IS_FLAG=()
# ([<flag-name>]=<is-multi-bool>)
declare -A OPTER_OPTS_IS_MULTI=()

OPTER_UNKNOWN_ARGS=()
OPTER_PARSED_ARGS=()
declare -A OPTER_PARSED_OPTS=()

# 
# $1 - optfile content
# 
opter_parse_optfile() {
  local optfile_path="${1}"
  if [[ ! -f "${optfile_path}" ]]; then
    echo "No file '${optfile_path}'" > /dev/stderr
    exit 1
  fi

  local content="$(cat "${optfile_path}")"
  local opts="$(while read -r l; do
    # filter out blank lines
    [[ -n "${l}" ]] && echo "${l}"
  done <<< "${content}" | while read -r l; do
    # filter out comment lines
    [[ "${l:0:1}" != '#' ]] && echo "${l}"
  done | grep -P '^[^=]+=')"

  while read -r opt_line; do
    optname="$(cut -d= -f1 <<< "${opt_line}")"
    if [[ "${OPTER_PARSED_OPTS[${optname}]}" ]]; then
      # option is already set
      continue
    fi
    
    optval="$(cut -d= -f2- <<< "${opt_line}")"
    [[ -z "${optval}" ]] && continue

    OPTER_PARSED_OPTS[${optname}]="${optval}"
  done <<< "${opts}"
}

#
# $1 - space separated exclude list
# $2 - initial optfile content
# $3 - options to create optfile
#
opter_gen_optfile() {
  local exclude="${1}"
  local init_opts_content="${2}"
  local optfile_opts="${3}"

  local init_opts="$([[ -n "${init_opts_content}" ]] && while read -r l; do
    # filter out blank lines
    [[ -n "${l}" ]] && echo "${l}"
  done <<< "${init_opts_content}" | while read -r l; do
    # filter out comment lines
    [[ "${l:0:1}" != '#' ]] && echo "${l}"
  done | grep -P '^[^=]+=')"

  # get gen-ca and gen-client available options
  declare -A OPTFILE_OPT_HELP=()
  declare -A OPTFILE_OPT_EXAMPLE=()
  declare -A OPTFILE_OPT_DEFAULT=()
  declare -A OPTFILE_OPT_IS_REQUIRED=()
  declare -A OPTFILE_OPT_IS_FLAG=()
  declare -A OPTFILE_OPT_IS_MULTI=()
  # OPTFILE_OPT=""

  opter_parse_available_opts "${optfile_opts}"

  # remove starting and trailing spaced
  # and convert to 'or' regex
  exclude="$(sed -E 's/^\s+//g' <<< "${exclude}" | sed -E 's/\s+$//g' | sed -E 's/\s+/|/g')"

  available_opts="$(for i in "${!OPTER_OPTS_PATTERN[@]}"; do
    echo "${i}"
  done | grep -Pv "^(${exclude})$")"

  [[ -n "${available_opts}" ]] && while read -r opt; do
    if [[ -n "${OPTER_OPTS_HELP[${opt}]}" ]]; then
      OPTFILE_OPT_HELP[${opt}]="${OPTER_OPTS_HELP[${opt}]}"
    fi
    if [[ -n "${OPTER_OPTS_EXAMPLE[${opt}]}" ]]; then
      OPTFILE_OPT_EXAMPLE[${opt}]="${OPTER_OPTS_EXAMPLE[${opt}]}"
    fi
    if [[ -n "${OPTER_OPTS_DEFAULT[${opt}]}" ]]; then
      OPTFILE_OPT_DEFAULT[${opt}]="${OPTER_OPTS_DEFAULT[${opt}]}"
    fi
    if [[ -n "${OPTER_OPTS_IS_REQUIRED[${opt}]}" ]]; then
      OPTFILE_OPT_IS_REQUIRED[${opt}]="${OPTER_OPTS_IS_REQUIRED[${opt}]}"
    fi
    if [[ -n "${OPTER_OPTS_IS_FLAG[${opt}]}" ]]; then
      OPTFILE_OPT_IS_FLAG[${opt}]="${OPTER_OPTS_IS_FLAG[${opt}]}"
    fi
    if [[ -n "${OPTER_OPTS_IS_MULTI[${opt}]}" ]]; then
      OPTFILE_OPT_IS_MULTI[${opt}]="${OPTER_OPTS_IS_MULTI[${opt}]}"
    fi
  done <<< "${available_opts}"

  local ctr=0; while read -r opt; do
    [[ ${ctr} -gt 0 ]] && echo
    (( ctr++ ))

    if [[ -n "${OPTFILE_OPT_HELP[${opt}]}" ]]; then
      while read -r l; do
          [[ -n "${l}" ]] && echo "# ${l}"
      done <<< "${OPTFILE_OPT_HELP[${opt}]}"
    fi

    if [[ -n "${OPTFILE_OPT_EXAMPLE[${opt}]}" ]]; then
      echo "# Example:"
      while read -r l; do
          [[ -n "${l}" ]] && echo "#   ${l}"
      done <<< "${OPTFILE_OPT_EXAMPLE[${opt}]}"
    fi

    more=""
    opt_string="${opt}"
    if [[ -n "${OPTFILE_OPT_IS_REQUIRED[${opt}]}" ]]; then
      more+=", required"
    fi

    if [[ -n "${OPTFILE_OPT_IS_FLAG[${opt}]}" ]]; then
      more+=", flag"
    fi

    if [[ -n "${OPTFILE_OPT_IS_MULTI[${opt}]}" ]]; then
      opt_string+='.1'
      more+=", multi"
    fi

    if [[ -n "${OPTFILE_OPT_DEFAULT[${opt}]}" ]]; then
      more+=", defaults to ${OPTFILE_OPT_DEFAULT[${opt}]}"
    fi

    [[ -n "${more}" ]] && echo "# (${more:2})"

    opt_string+="="
    if grep -Pq "^${opt_string}" <<< "${init_opts}"; then
      pattern="^${opt_string}"
      if [[ -n "${OPTFILE_OPT_IS_MULTI[${opt}]}" ]]; then
        pattern="${opt}\.\d+"
      fi
      opt_string="$(grep -P "^${pattern}" <<< "${init_opts}")"
    elif [[ -n "${OPTFILE_OPT_DEFAULT[${opt}]}" ]]; then
      opt_string+="${OPTFILE_OPT_DEFAULT[${opt}]}"
    fi

    echo "${opt_string}"
  done <<< "$(sort -n <<< "${available_opts}" | uniq)"
}

#
# Required variables:
# * THE_OPTS
#
opter_parse_input() {
  local endopts=0
  declare -A parsed_opts_ctr=()

  opter_parse_available_opts "${THE_OPTS}"

  # reset global values
  OPTER_UNKNOWN_ARGS=()
  OPTER_PARSED_OPTS=()
  OPTER_PARSED_ARGS=()

  while :; do
    [[ -z "${1+x}" ]] && break

    local opt="${1}"
    shift

    if [[ "${opt}" == '--' ]]; then
      endopts=1
      continue
    fi

    if test ${endopts} != 0 || grep -qvP -- '^--?.+' <<< "${opt}"; then
      # handle param
      OPTER_PARSED_ARGS+=("${opt}")
      continue
    fi

    if grep -qPx -- '^-h|-\?|--help$' <<< "${opt}"; then
      # handle help
      opter_print_help
      exit
    fi

    if ! grep -qP -- "^($(sed 's/ /|/g' <<< "${OPTER_OPTS_PATTERN[@]}"))$" <<< "${opt}"; then
      OPTER_UNKNOWN_ARGS+=("${opt}")
    fi

    # find matching optname
    for optname in "${!OPTER_OPTS_PATTERN[@]}"; do
      local regex="${OPTER_OPTS_PATTERN[${optname}]}"

      if ! grep -qP -- "^${regex}$" <<< "${opt}"; then
        continue
      fi

      if [[ "${OPTER_OPTS_IS_FLAG[${optname}]}" == 1 ]]; then
        # flag option
        OPTER_PARSED_OPTS["${optname}"]=1
        continue
      fi

      if [[ "${OPTER_OPTS_IS_MULTI[${optname}]}" == 1 ]]; then
        # multi option
        (( parsed_opts_ctr[${optname}]++ ))
        OPTER_PARSED_OPTS["${optname}.${parsed_opts_ctr[${optname}]}"]="${1}"
        shift
        continue
      fi

      OPTER_PARSED_OPTS["${optname}"]="${1}"
      shift
    done
  done
}

#
# Required variables:
# * THE_OPTS
# Optional variables:
# * THE_DEMO
# * THE_DESCRIPTION
# * THE_USAGE
opter_print_help() {
  while read -r l; do
    [[ -n "${l}" ]] && echo "${l}"
  done <<< "${THE_DESCRIPTION}"

  if [[ -n "${THE_USAGE}" ]]; then
    echo
    echo "Usage:"
    while read -r l; do
      [[ -n "${l}" ]] && echo "  ${l}"
    done <<< "${THE_USAGE}"
  fi

  if [[ -n "${THE_OPTS}" ]]; then
    echo
    echo "Options:"
    opter_print_opts_help "${THE_OPTS}" | while IFS= read -r l; do
      echo "  ${l}"
    done
  fi

  if [[ -n "${THE_DEMO}" ]]; then
    echo
    echo "Demo:"
    while read -r l; do
      [[ -n "${l}" ]] && echo "  ${l}"
    done <<< "${THE_DEMO}"
  fi
}

opter_print_opts_help() {
  local opts="${1}"
  opter_parse_available_opts "${opts}"
  
  for i in ${!__OPTER_POS_TO_OPT[@]}; do
    echo "${__OPTER_POS_TO_OPT[${i}]}"
  done | sort -n | while read -r optname; do
    local opt_line="${OPTER_OPTS_PATTERN[${optname}]}"
    local opt_line_suffix=''
    if [[ -n "${OPTER_OPTS_IS_REQUIRED[${optname}]}" ]]; then
      opt_line_suffix+=', required'
    fi
    if [[ -n "${OPTER_OPTS_IS_FLAG[${optname}]}" ]]; then
      opt_line_suffix+=', flag'
    fi
    if [[ -n "${OPTER_OPTS_IS_MULTI[${optname}]}" ]]; then
      opt_line_suffix+=', multi'
    fi
    if [[ -n "${OPTER_OPTS_DEFAULT[${optname}]}" ]]; then
      opt_line_suffix+=", defaults to ${OPTER_OPTS_DEFAULT[${optname}]}" 
    fi

    if [[ -n "${opt_line_suffix}" ]]; then
      opt_line+=" (${opt_line_suffix:2})"
    fi

    printf "%s\n" "${opt_line}"

    if [[ -n "${OPTER_OPTS_HELP[${optname}]}" ]]; then
      while read -r h; do
        [[ -n "${h}" ]] && printf "%-2s%s\n" '' "${h}"
      done <<< "${OPTER_OPTS_HELP[${optname}]}"
    fi

    if [[ -n "${OPTER_OPTS_EXAMPLE[${optname}]}" ]]; then
      printf "%-2s%s\n" '' "Example:"
      offset=4
      while read -r h; do
        [[ -n "${h}" ]] && printf "%-4s%s\n" '' "${h}"
      done <<< "${OPTER_OPTS_EXAMPLE[${optname}]}"
    fi
  done
}

opter_parse_available_opts() {
  local opts="${1}"

  # reset
  __OPTER_POS_TO_OPT=()
  OPTER_OPTS_AVAILABLE=()
  OPTER_OPTS_HELP=()
  OPTER_OPTS_EXAMPLE=()
  OPTER_OPTS_DEFAULT=()
  OPTER_OPTS_IS_REQUIRED=()
  OPTER_OPTS_IS_FLAG=()

  ctr=0; while read -r line; do
    first_ch="${line:0:1}"

    if [[ "${first_ch}" == '-' ]]; then
      regex="$(cut -d: -f1 <<< "${line}")"
      name="$(cut -d: -f2 <<< "${line}")"
      suffix="$(cut -d: -f3 <<< "${line}")"

      [[ -z "${name}" ]] && continue

      (( ctr++ ))
      __OPTER_POS_TO_OPT[${ctr}]="${name}"

      OPTER_OPTS_PATTERN[${name}]="${regex}"
      # to avoid duplicates when the list contains
      # an option more than once
      OPTER_OPTS_HELP[${name}]=
      OPTER_OPTS_EXAMPLE[${name}]=
      OPTER_OPTS_DEFAULT[${name}]=

      if [[ "${suffix}" == 'r' ]]; then
        OPTER_OPTS_IS_REQUIRED[${name}]=1
      elif [[ "${suffix}" == 'f' ]]; then
        OPTER_OPTS_IS_FLAG[${name}]=1
      elif [[ "${suffix}" == 'm' ]]; then
        OPTER_OPTS_IS_MULTI[${name}]=1
      fi
    elif [[ "${first_ch}" == '#' ]]; then
      OPTER_OPTS_HELP[${name}]+="${line:1}"$'\n'
    elif [[ "${first_ch}" == ':' ]]; then
      OPTER_OPTS_EXAMPLE[${name}]+="${line:1}"$'\n'
    elif [[ "${first_ch}" == '=' ]]; then
      OPTER_OPTS_DEFAULT[${name}]="${line:1}"
    fi
  done <<< "${opts}"
}

### TESTS ###

if [[ "${1}" == test ]]; then
  OPTER_AVAILABLE_TESTS_OPTS="
    --flag-opt:flag_opt:f
      # Flag opt
      # Next line
    --required-opt:required_opt:r
      # Required opt
      : --required-opt required-val
      =lala
    --multi-opt\d*:multi_opt:m
      # Multi opt line 1
      # Multi opt line 2
      : --multi-opt multi-val1
      : --multi-opt1 multi-val2
    -s|--simple-opt:simple_opt
      # Simple opt
      : --simple-opt simple-val
      : -s simple-val
  "

  opter_parse_available_opts "${OPTER_AVAILABLE_TESTS_OPTS}"

  echo "Parse available opts:"
  echo '```'
  for pos in $(rev <<< "${!__OPTER_POS_TO_OPT[@]}"); do
    optname="${__OPTER_POS_TO_OPT[${pos}]}"
    flags=''

    [[ -n "${OPTER_OPTS_IS_REQUIRED[${optname}]}" ]] && flags+=', required'
    [[ -n "${OPTER_OPTS_IS_FLAG[${optname}]}" ]] && flags+=', flag'
    [[ -n "${OPTER_OPTS_IS_MULTI[${optname}]}" ]] && flags+=', multi'
    [[ -n "${OPTER_OPTS_DEFAULT[${optname}]}" ]] && flags+=", defaults to ${OPTER_OPTS_DEFAULT[${optname}]}"

    opt_line="${optname}"
    [[ -n "${flags}" ]] && opt_line+=" (${flags:2})"
    echo "* ${opt_line}"
    echo "  Pattern: ${OPTER_OPTS_PATTERN[${optname}]}"
    echo "  Help:"; while read -r l; do
      [[ -n "${l}" ]] && echo "    ${l}"
    done <<< "${OPTER_OPTS_HELP[${optname}]}"
    echo "  Example:"; while read -r l; do
      [[ -n "${l}" ]] && echo "    ${l}"
    done <<< "${OPTER_OPTS_EXAMPLE[${optname}]}"
  done
  echo '```'
  echo '##########'
  echo

  echo "Print opts help:"
  echo '```'
  opter_print_opts_help "${OPTER_AVAILABLE_TESTS_OPTS}"
  echo '```'
  echo '##########'
  echo

  echo "Print help:"
  THE_OPTS="${OPTER_AVAILABLE_TESTS_OPTS}"
  THE_DEMO="Some demo"
  THE_DESCRIPTION="Description"
  THE_USAGE="some usage"
  echo '```'
  opter_print_help
  echo '```'

  echo "Parse input (1):"
  THE_OPTS="${OPTER_AVAILABLE_TESTS_OPTS}"
  echo '```'
  opter_parse_input \
    --flag-opt \
    --required-opt required-val \
    --multi-opt1 val1 \
    --multi-opt2 val2 \
    --simple-opt simple-val \
    --unknown-opt \
    positional-arg1 \
    positional-arg2
  echo '# opts:'
  for o in "${!OPTER_PARSED_OPTS[@]}"; do
    echo "${o} = ${OPTER_PARSED_OPTS[${o}]}"
  done
  echo '# args:'
  for a in "${OPTER_PARSED_ARGS[@]}"; do
    echo "${a}"
  done
  echo '# unknown:'
  for u in "${OPTER_UNKNOWN_ARGS[@]}"; do
    echo "${u}"
  done
  echo '```'
  echo "Parse input (2):"
  echo '```'
  opter_parse_input \
    --flag-opt \
    --required-opt required-val \
    --multi-opt val \
    -s simple-val \
    -- \
    --unknown-opt
  echo '# opts:'
  for o in "${!OPTER_PARSED_OPTS[@]}"; do
    echo "${o} = ${OPTER_PARSED_OPTS[${o}]}"
  done
  echo '# args:'
  for a in "${OPTER_PARSED_ARGS[@]}"; do
    echo "${a}"
  done
  echo '# unknown:'
  for u in "${OPTER_UNKNOWN_ARGS[@]}"; do
    echo "${u}"
  done
  echo '```'
fi
