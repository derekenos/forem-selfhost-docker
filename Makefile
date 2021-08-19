
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
# Copy the secret files automatically generated during the Docker image build
# process to a local directory called "secrets"
###############################################################################

extract-secrets:
	@mkdir -p secrets
	@docker run --rm -v `pwd`/secrets:/secrets forem-selfhost \
	/bin/bash -c \
	"cp /home/$(USER)/.ssh/forem{,.pub} "\
	"/home/$(USER)/selfhost/inventory/forem/setup.yml "\
	"/home/$(USER)/.forem_selfhost_ansible_vault_password "\
	"/secrets"


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


###############################################################################
# DigitalOcean helpers
###############################################################################

# Return the public IP of the DigitalOcean Droplet tagged "forem"
digitalocean_get_ip = \
	`docker run forem-selfhost-digitalocean \
     doctl compute droplet list --tag-name forem --no-header --format PublicIPv4`

# Return the command for SSHing into the DigitalOcean Droplet
digitalocean_ssh_command = \
	docker run -it forem-selfhost \
	ssh -t -o "StrictHostKeyChecking=no" -i /home/$(USER)/.ssh/forem \
	core@$(call digitalocean_get_ip) $(1)

# Return the command to execute a command within a container
# args: ( <user>, <container-name>, <command> )
digitalocean_podman_exec = \
  "sudo podman exec -u $1 -it \$$(sudo podman ps -q -f name=$2) $3"

# Return the command to execute a command within a container
# args: ( <container-name>, )
digitalocean_podman_logs = \
  "sudo podman logs -f \$$(sudo podman ps -q -f name=$1)"


###############################################################################
# Show DigitalOcean Droplet IP
###############################################################################
digitalocean-ip:
	@echo $(call digitalocean_get_ip)


###############################################################################
# SSH into the DigitalOcean Droplet
###############################################################################
digitalocean-shell:
	@$(call digitalocean_ssh_command)


###############################################################################
# Connect to the DigitalOcean Droplet PostgreSQL DB
###############################################################################
digitalocean-db-shell:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_exec,"postgres","postgres","psql -Uforem_production"))


###############################################################################
# Services admin
###############################################################################
# Status
digitalocean-service-status:
	@$(call digitalocean_ssh_command, "sudo systemctl list-units forem*")

# Restart
digitalocean-service-forem-restart:
	@$(call digitalocean_ssh_command, "sudo systemctl restart forem")

###############################################################################
# Podman admin
###############################################################################
# List containers
digitalocean-container-list:
	@$(call digitalocean_ssh_command, "sudo podman ps")

# Tail container logs
digitalocean-container-imgproxy-logs:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_logs,"imgproxy"))\
	|| exit 0

digitalocean-container-openresty-logs:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_logs,"openresty"))\
	|| exit 0

digitalocean-container-postgres-logs:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_logs,"postgres"))\
	|| exit 0

digitalocean-container-rails-logs:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_logs,"rails"))\
	|| exit 0

digitalocean-container-redis-logs:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_logs,"redis"))\
	|| exit 0

digitalocean-container-traefik-logs:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_logs,"traefik"))\
	|| exit 0

digitalocean-container-worker-logs:
	@$(call digitalocean_ssh_command,\
	$(call digitalocean_podman_logs,"worker"))\
	|| exit 0
