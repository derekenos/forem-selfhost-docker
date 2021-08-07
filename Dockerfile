
FROM fedora:34

ARG DOCKER_USER
ARG DOCKER_UID
ARG DOCKER_GID
ARG FOREM_DOMAIN_NAME
ARG FOREM_SUBDOMAIN_NAME
ARG FOREM_DEFAULT_EMAIL

# Assert that all build args have been specified.
RUN echo "verify required --build-arg(s) were specified" \
    && test -n "$DOCKER_USER" \
    && test -n "$DOCKER_UID" \
    && test -n "$DOCKER_GID" \
    && test -n "$FOREM_DOMAIN_NAME" \
    && test -n "$FOREM_SUBDOMAIN_NAME" \
    && test -n "$FOREM_DEFAULT_EMAIL"

RUN dnf install -y \
    git \
    python3 \
    python3-pip \
    butane \
    pwgen \
    vim-common \
    which

# Create a non-root user
RUN echo "$DOCKER_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Use exit command to ignore error if group already exists.
RUN groupadd --gid=$DOCKER_GID $DOCKER_USER; exit 0
RUN useradd --uid=$DOCKER_UID --gid=$DOCKER_GID -m --groups wheel $DOCKER_USER
USER $DOCKER_USER

# Switch to the home dir
WORKDIR /home/$DOCKER_USER

# Configure SSH
RUN mkdir .ssh
# Generate an SSH key using the specified email address
RUN ssh-keygen -t ed25519 -C "$FOREM_DEFAULT_EMAIL" -N "" -f .ssh/forem
# Add git.archive.org to known_hosts.
RUN ssh-keyscan -t rsa github.com >> .ssh/known_hosts

# Clone the Forem selfhost repo into the home dir
RUN git clone https://github.com/forem/selfhost.git

# Switch to selfhost dir
WORKDIR selfhost

# Install the python dependencies
RUN pip3 install -r requirements.txt

# Create a new setup.yml and auto-generate the secrets
RUN cp inventory/example/setup.yml inventory/forem/setup.yml

# Inject configuration variables specified via build args into setup.yml
RUN sed -i \
    -e "s/\(forem_domain_name:\) REPLACEME/\1 $FOREM_DOMAIN_NAME/" \
    -e "s/\(forem_subdomain_name:\) REPLACEME/\1 $FOREM_SUBDOMAIN_NAME/" \
    -e "s/\(default_email:\) REPLACEME/\1 $FOREM_DEFAULT_EMAIL/" \
    inventory/forem/setup.yml

# Generate and ansible vault password
RUN pwgen -1 24 > ../.forem_selfhost_ansible_vault_password

ARG VAULT_CMD=..\/.local\/bin\/ansible-vault

# Auto-generate vault_secret_key_base
RUN sed -i 's/vault_secret_key_base: REPLACEME/echo -n $(pwgen -1 128) | $VAULT_CMD encrypt_string --stdin-name vault_secret_key_base | sed "s#^#          #"/e' \
    inventory/forem/setup.yml

# # Auto-generate vault_imgproxy_key
RUN sed -i 's#vault_imgproxy_key: REPLACEME#echo -n $(xxd -g 2 -l 64 -p /dev/random | tr -d "\n") | $VAULT_CMD encrypt_string --stdin-name vault_imgproxy_key | sed "s/^/          /"#e' \
    inventory/forem/setup.yml

# # Auto-generate vault_imgproxy_salt
RUN sed -i 's#vault_imgproxy_salt: REPLACEME#echo -n $(xxd -g 2 -l 64 -p /dev/random | tr -d "\n") | $VAULT_CMD encrypt_string --stdin-name vault_imgproxy_salt | sed "s/^/          /"#e' \
    inventory/forem/setup.yml

# # Auto-generate vault_forem_postgres_password
RUN sed -i 's/vault_forem_postgres_password: REPLACEME/echo -n $(pwgen -1 128) | $VAULT_CMD encrypt_string --stdin-name vault_forem_postgres_password | sed "s#^#          #"/e' \
    inventory/forem/setup.yml


# #### Digital Ocean stuff BEGIN ####

# Download and install doctl
RUN curl -s -L https://github.com/digitalocean/doctl/releases/download/v1.62.0/doctl-1.62.0-linux-amd64.tar.gz -O
RUN tar xf doctl-1.62.0-linux-amd64.tar.gz
RUN sudo mv doctl /usr/local/bin
RUN rm doctl-1.62.0-linux-amd64.tar.gz

#### Digital Ocean stuff END ####


CMD ["/bin/bash"]
