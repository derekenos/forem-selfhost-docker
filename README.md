# forem-selfhost-docker
A Dockerization of the deployment steps detailed in [forem/selfhost/README.md](https://github.com/forem/selfhost/blob/5e5ce60a5df738cd36261c80e94dac917e78868f/README.md)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [GNU Make](https://www.gnu.org/software/make/) (_optional - you can execute the commands in the Makefile directly_)

Developed using `Make 4.1` and `Docker 20.10.5` on `Ubuntu 18.04`

## Usage

### Build the Docker Image

```
make \
  -e FOREM_DOMAIN_NAME=example.com \
  -e FOREM_SUBDOMAIN_NAME=community \
  -e FOREM_DEFAULT_EMAIL=admin@example.com \
  build-forem-selfhost
```

#### During the Dockerfile build:

- [an SSH key will be generated](https://github.com/derekenos/forem-selfhost-docker/blob/91b28dfad86b3c7446a11d15dfa78037f2ec69f0/Dockerfile#L52)
- [the Forem repo will be cloned and default `setup.yml` created](https://github.com/derekenos/forem-selfhost-docker/blob/91b28dfad86b3c7446a11d15dfa78037f2ec69f0/Dockerfile#L56-L66)
- [`setup.yml` will be injected with the configuration values](https://github.com/derekenos/forem-selfhost-docker/blob/91b28dfad86b3c7446a11d15dfa78037f2ec69f0/Dockerfile#L68-L73)
- [an Ansible Vault password will be automatically generated](https://github.com/derekenos/forem-selfhost-docker/blob/91b28dfad86b3c7446a11d15dfa78037f2ec69f0/Dockerfile#L75-L76)
- [all required secret values will be automatically generated and injected into `setup.yml`](https://github.com/derekenos/forem-selfhost-docker/blob/91b28dfad86b3c7446a11d15dfa78037f2ec69f0/Dockerfile#L80-L94)

Note that the automatically generated secret values you need to administer your Forem services (e.g. Vault password, `vault_secret_key_base`, etc.)
and eventually access your deployment machine (e.g. SSH key) now exist exclusively within the Docker image you just created, so you should maybe:
- not share the Docker image with anyone, lest they get your secretz
- copy those values out of the image and store them somewhere safe (see "Extracting secrets")

### Extract the secrets

Use `extract-secrets` to copy the secret files automatically generated during the Docker image build process to
your local filesystem and store them somewhere safe.

```
make extract-secrets
```

This will create a local directory called `secrets` with the contents:
```
$ ls secrets/ -aF | grep -v /$
forem
forem.pub
.forem_selfhost_ansible_vault_password
setup.yml
```

### Deploy to DigitalOcean

[Create an auth token](https://github.com/forem/selfhost/blob/5e5ce60a5df738cd36261c80e94dac917e78868f/README.md#setup-1) 
and store it in a local (to this repo) file called `.digitalocean-access-token`

#### Build the DigitalOcean deployment Image

```
make build-forem-selfhost-digitalocean
```

#### Deploy to DigitalOcean

```
make deploy-to-digitalocean
```

