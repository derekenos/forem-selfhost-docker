
###############################################################################
# Build the base / platform-agnostic Docker image
#
# You can specify the FOREM_* build argument values...
#
#   by specifying them as temporary environment variables prefixes to `make`
#   https://stackoverflow.com/a/21360477/2327940
#
#     FOREM_DOMAIN_NAME=example.com ... make build-forem-selfhost
#
#   by specifying them as environment overrides arguments to the `make` command
#   https://www.gnu.org/software/make/manual/html_node/Environment.html
#
#      make -e FOREM_DOMAIN_NAME=example.com ... build-forem-selfhost
#
#   or by hard-coding them in this file
#
#     ...
#	  --build-arg "FOREM_DOMAIN_NAME=example.com" \
#     ...
#
# Note that FOREM_SUBDOMAIN_NAME can be left blank if you're not using a
# subdomain, e.g.: codechatz.com
#
###############################################################################

build-forem-selfhost:
	@docker build \
	--build-arg "DOCKER_USER=`id -un`" \
	--build-arg "DOCKER_UID=`id -u`" \
	--build-arg "DOCKER_GID=`id -g`" \
	--build-arg "FOREM_DOMAIN_NAME=$(FOREM_DOMAIN_NAME)" \
	--build-arg "FOREM_SUBDOMAIN_NAME=$(FOREM_SUBDOMAIN_NAME)" \
	--build-arg "FOREM_DEFAULT_EMAIL=$(FOREM_DEFAULT_EMAIL)" \
	. \
	-t forem-selfhost


###############################################################################
# Build the DigitalOcean deployment Docker image
#
# Create a file in this directory called ".digitalocean-access-token"
# that contains your Personal Access Token.
#
# https://docs.digitalocean.com/reference/api/create-personal-access-token/
#
###############################################################################

build-forem-selfhost-digitalocean:
	@DOCKER_BUILDKIT=1 docker build \
	-f Dockerfile-digitalocean . \
	--secret id=digitalocean-access-token,src=.digitalocean-access-token \
	-t forem-selfhost-digitalocean


###############################################################################
# Deploy to DigitalOcean
###############################################################################

deploy-to-digitalocean:
	@docker run forem-selfhost-digitalocean
