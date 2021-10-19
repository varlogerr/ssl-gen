#
# Requires THE_SCRIPT variable 
#

export GEN_OPTFILE_DESCRIPTION="
  Generate options file
"
export GEN_OPTFILE_USAGE="
  ${THE_SCRIPT} [DESTINATION_FILE]
"
export GEN_OPTFILE_DEMO="
  $(
    optfile_path="~/options/ssl-gen.conf"
    while read -r l; do
      echo "${l}"
    done <<< "
      # generate to stdout
      ${THE_SCRIPT}
      # generate to ${optfile_path} file
      ${THE_SCRIPT} > ${optfile_path}
      # generate to ${optfile_path} file.
      # $(dirname "${optfile_path}") directory will be created if doesn't exist
      ${THE_SCRIPT} ${optfile_path}
    "
  )
"
