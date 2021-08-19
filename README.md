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
- copy those values out of the image and store them somewhere safe (see "Extract the secrets")

### Extract the secrets

Use `extract-secrets` to copy the secret files automatically generated during the Docker image build process to
your local filesystem and store them somewhere safe.

```
make extract-secrets
```

This will create a local directory called `secrets` with the contents:
```
forem
forem.pub
.forem_selfhost_ansible_vault_password
setup.yml
```

### Deploying to DigitalOcean

[Create an auth token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) and store it in a local (to this repo) file called `.digitalocean-access-token`

#### Build the DigitalOcean deployment image

```
make build-forem-selfhost-digitalocean
```

#### Do the deploy
```
make deploy-to-digitalocean
```

#### Update your DNS and restart the traefik service

Complete [steps 10 & 11 in the Quick Start guide](https://github.com/forem/selfhost/blob/5e5ce60a5df738cd36261c80e94dac917e78868f/README.md#quick-start):
> 10. Once your Forem VM is set up with your chosen cloud provider, you will need to point DNS at the IP address that is output at the end of the provider playbook.
> 11. Once DNS is pointed at your Forem VM, you will need to restart the Forem Traefik service (sudo systemctl restart forem-traefik.service) via SSH on your Forem server to generate a TLS cert.

You can use `make digitalocean-service-restart-traefik` to do the restart, after which you should be able to surf over to your domain and see something cool!


#### Interact with the server

##### Show the IP address
```
make digitalocean-ip
```

##### Start an SSH session
```
make digitalocean-shell
```

##### Connect to the PostgreSQL console
```
make digitalocean-db-shell
```

##### Show the status of related services
```
make digitalocean-service-status
```

##### Restart a service
```
make digitalocean-service-restart-forem
```
```
make digitalocean-service-restart-traefik
```

##### List all of the containers
```
make digitalocean-container-list
```

##### Tail the logs of a specific container
```                                                                                                               
make digitalocean-container-imgproxy-logs                                                                         
```
```                                                                                                               
make digitalocean-container-openresty-logs                                                                        
```
```                                                                                                               
make digitalocean-container-postgres-logs                                                                         
```
```                                                                                                               
make digitalocean-container-rails-logs                                                                            
```
```                                                                                                               
make digitalocean-container-redis-logs                                                                            
```
```                                                                                                               
make digitalocean-container-traefik-logs                                                                          
```
```                                                                                                               
make digitalocean-container-worker-logs                                                                           
```

#### Some notes about my experience

##### Failed initial traefik restart

If the `traefik` service restart fails, run `make digitalocean-service-status` to see how things look.

A normal, healthy state looks like:

```
  UNIT                     LOAD   ACTIVE SUB     DESCRIPTION             
  forem-imgproxy.service   loaded active running Forem Imgproxy Service
  forem-openresty.service  loaded active running Forem OpenResty Service
  forem-pod.service        loaded active running Forem pod service
  forem-postgresql.service loaded active running Forem Postgresql Service
  forem-rails.service      loaded active running Forem Rails Service
  forem-redis.service      loaded active running Forem Redis Service
  forem-traefik.service    loaded active running Forem Traefik Service
  forem-worker.service     loaded active running Forem Worker Service
  forem.service            loaded active exited  Forem Service
```

An unhealthy state shows `inactive`s and `dead`s.

There was a bug ([which looks to have been fixed](https://github.com/forem/selfhost/commit/ccd1063e0a27f26e784d25fe22cbc51d7eea4e53)) in which the `container` service didn't do what it was supposed to. I was able to resolve this by SSHing in and doing a `sudo systemctl start forem-container.service`

##### HTTPS-only caused problems with SSL certificate registration

As I understand it, the `traefik` service attempts to register an SSL cert via Let's Encrypt in order to enable HTTPS.
The problem is that, during the registration process, Let's Encrypt needs to be able to access the `/.well-known/acme-challenge/` path on your site using plain ol' HTTP. If you have something like "Always use HTTP" (e.g. on Cloudflare) enabled, it's not going to work.

In Cloudflare, I fixed this as follows:

- In `SSL/TLS` -> `Edge Certificates`:
  - Disable `Always use HTTPs`![Screenshot from 2021-08-19 16-44-44](https://user-images.githubusercontent.com/585182/130141521-e0c5f8df-9110-49c5-98b3-08a2eb13848d.png)
  - Disable `Automatic HTTPS Rewrites` (maybe not necessary?)![Screenshot from 2021-08-19 16-47-10](https://user-images.githubusercontent.com/585182/130141714-2660d183-77de-4132-a404-d381cd84bda0.png)
- In `Rules`
  - Create two rules - one to prevent SSL on the `acme-challenge` path, and another to enforce `HTTPS` everywhere else![Screenshot from 2021-08-19 16-49-21](https://user-images.githubusercontent.com/585182/130141991-1b87beea-5829-4f8f-8826-708172202280.png)  

