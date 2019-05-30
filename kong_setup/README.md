# Dockerized Kong
---
In the lighthouse project we use kong as a gateway for our APIs

Traditionally it has been quite annoying to run kong for a production like setup this simplifies the process.

### Assumptions
- Have the proper kongfig installed [Link](https://github.com/adhocteam/kongfig)
- Have docker / docker-compose installed

### Installation
```
*** From the project root ***
make db && docker-compose up vets-api
(in a separate pane) docker-compose up kong
(in a separate pane) cd kong_setup && rake initial_setup
```

To test to ensure everything is working:
```
curl localhost:8000/services/claims/docs/v0/api
```
You should receive a response with a bunch of swagger docs json.


### Usage Beyond Initial Setup
From here you can now edit `local_kong.yml` to your hearts content and run `rake apply_config` to apply it to your dockerized kong. If you do make updates that need/should be persisted, simply update the `*.example` file that's used to generate the local config.

#### Caveat
Everytime kong is rebuilt, it assigns new ids to consumers, in order to support rebuilding all the time with the anonymous user, in the example file we assign a bunch of 1's as the uuid and then get the actual id and gsub it in. Something to be aware of when adding new sections to the example file.