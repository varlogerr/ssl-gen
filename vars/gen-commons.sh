export GEN_COMMONS_OPTS="
  --ca-dir:ca-dir
    # CA certificates destination directory
    : --ca-dir ~/certs
    =.
  --ca-file-prefix:ca-file-prefix
    # CA files prefix.
    : --ca-file-prefix acme-
  --ca-phrase:ca-phrase
    # CA pkey passphrase
    : --ca-phrase changeme
  --optfile\d*:optfile:m
    # File to read options from
    : --optfile ~/options/ssl-gen.conf
  -f|--force:force:f
    # Override if certificates exist
  -s|--silent:silent:f
    # Try to avoid interactions:
    # * silently halt if certificates exist
"
