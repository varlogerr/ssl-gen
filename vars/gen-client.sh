#
# Required variables:
# * THE_SCRIPT 
# * THE_DIR 
#

. "${THE_DIR}/vars/gen-commons.sh"

export GEN_CLIENT_DESCRIPTION="
  Generate client certificate
"
export GEN_CLIENT_USAGE="
  ${THE_SCRIPT} --client-cn <cn> [OPTIONS]
  ${THE_SCRIPT} --optfile <option-file> \\
  [OPTIONS]
"
export GEN_CLIENT_OPTS="
  ${GEN_COMMONS_OPTS}
  --client-cert-days:client-cert-days
    # Client certificate days.
    # Values greater than 365 should be avoided
    : --client-cert-days 340
    =365
  --client-dir:client-dir
    # Client certificates destination directory
    : --client-dir ~/certs/client
    =.
  --client-cn:client-cn:r
    # Client common name
    : --client-cn '*.site.local'
  --client-filename:client-filename
    # Client certificates file name.
    # Defaults to --client-cn value
    # with '*' replaced with '_'
    : --client-filename localhost
"
export GEN_CLIENT_DEMO="
  # generate to ~/certs/client directory with all
  # defaults except required options
  ${THE_SCRIPT} --client-dir ~/certs/client \\
  --client-cn '*.site.local' --client-domain 'site.local'
  $(
    optfile='~/options/ssl-gen.conf'
    phrase=changeme
    while read -r l; do
      echo "${l}"
    done <<< "
      # generate certs with options
      # from ${optfile} file
      # and prompt for phrase
      ${THE_SCRIPT} --req-phrase \\
      --optfile ${optfile}
    "
  )
"
