# SSL gen

Old and naive set of scripts for self-signed ssl certificates generation. Not (or rarely?) supported as [mkcert](https://github.com/FiloSottile/mkcert) is a much better alternative.

## Usage

```bash
# clone the repository
git clone https://github.com/varlogerr/ssl-gen
# add `hook.bash` to your `.bashrc file`.
# the hook will add the ssl-gen-* scripts
# directory to your PATH
cd ssl-gen
echo ". '$(pwd)/hook.bash'" >> ~/.bashrc
# load `.bashrc` to the current session
# (next time you login to bash the hook will be
# loaded automatically from `.bashrc` file)
. ~/.bashrc
# explore the scripts
ssl-gen-optfile.sh -h
ssl-gen-ca.sh -h
ssl-gen-client.sh -h
# optionally generate and edit an option file
# and use it for certs generation
ssl-gen-optfile.sh ~/options/ssl-gen.conf
vi ~/options/ssl-gen.conf
ssl-gen-ca.sh --optfile ~/options/ssl-gen.conf
ssl-gen-client.sh --optfile ~/options/ssl-gen.conf
# or without option file
ssl-gen-ca.sh
ssl-gen-client.sh
```
