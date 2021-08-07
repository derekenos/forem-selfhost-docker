
build-docker-image:
	@docker build \
	--build-arg "DOCKER_USER=`id -un`" \
	--build-arg "DOCKER_UID=`id -u`" \
	--build-arg "DOCKER_GID=`id -g`" \
	--build-arg "FOREM_DOMAIN_NAME=" \
	--build-arg "FOREM_SUBDOMAIN_NAME=" \
	--build-arg "FOREM_DEFAULT_EMAIL=" \
	. \
	-t forem-deploy
