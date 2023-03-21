# Docker Setup

## Docker Desktop (Engine + Compose)

- [Mac](https://docs.docker.com/docker-for-mac/install/)
- [Windows](https://docs.docker.com/docker-for-windows/install/)

## Linux (Ubuntu)

- [Docker Engine](https://docs.docker.com/engine/install/#server)
- [Docker Compose](https://docs.docker.com/compose/install/#install-compose-on-linux-systems)

## ClamAV Antivirus Configuration
### EKS

Prior to EKS, ClamAV (the virus scanner) was deployed in the same process as Vets API. With EKS, ClamAV has been extracted out into it’s own service. Locally you can see the docker-compose.yml config for clamav.

**TODO**: Running clamav natively, as we did in Vets API master still needs to be configured. For the time being, **please run via docker**:

Please set the [clamav intitalizer](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/config/initializers/clamav.rb) initializers/clamav.rb file to the following:

``` 
## If running via docker
if Rails.env.development?
  ENV["CLAMD_TCP_HOST"] = "clamav"
  ENV["CLAMD_TCP_PORT"] = "3310"
end
```

After that, run the make/docker-compose commands per usual.
