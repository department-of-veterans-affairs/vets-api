# Docker Setup

## Docker Desktop (Engine + Compose)

- [Mac](https://docs.docker.com/docker-for-mac/install/)
- [Windows](https://docs.docker.com/docker-for-windows/install/)

## Linux (Ubuntu)

- [Docker Engine](https://docs.docker.com/engine/install/#server)
- [Docker Compose](https://docs.docker.com/compose/install/#install-compose-on-linux-systems)

### Configuring ClamAV antivirus

Prior to EKS, ClamAV (the virus scanner) was deployed in the same process as Vets API. With EKS, ClamAV has been extracted out into it’s own service. Locally you can see the docker-compose.yml config for clamav.

1. In settings.local.yml add the following:

```
clamav:
  mock: false
  host: 'clamav'
  port: '3310'
```

These setting are the default, so they be can removed as well
