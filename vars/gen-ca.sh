#
# Required variables:
# * THE_SCRIPT 
# * THE_DIR 
#

. "${THE_DIR}/vars/gen-commons.sh"

export GEN_CA_DESCRIPTION="
  Generate CA certificate
"
export GEN_CA_USAGE="
  ${THE_SCRIPT} --ca-cn <cn> [OPTIONS]
  ${THE_SCRIPT} --optfile <option-file> \\
  [OPTIONS]
"
export GEN_CA_OPTS="
  ${GEN_COMMONS_OPTS}
  --ca-cert-days:ca-cert-days
    # CA certificate days
    : --ca-cert-days 566
    =36500
  --ca-cn:ca-cn:r
    # CA common name
    : --ca-cn Acme
"
export GEN_CA_DEMO="
  # generate to ~/certs directory with common name
  # 'MySite' and password 'changeme', expiring in '69'
  # days with file prefix 'mysite-'.
  # \`ca-dir\` directory will be created if doesn't exist
  ${THE_SCRIPT} --ca-dir ~/certs --ca-cn MySite \\
  --ca-phrase changeme --ca-cert-days 69 \\
  --ca-file-prefix mysite-
  $(
    optfile='~/options/ssl-gen.conf'
    phrase=changeme
    while read -r l; do
      echo "${l}"
    done <<< "
      # generate certs with options
      # from ${optfile} file
      # and phrase overriden with '${phrase}'
      ${THE_SCRIPT} --optfile ${optfile} \\
      --ca-phrase '${phrase}'
    "
  )
"
