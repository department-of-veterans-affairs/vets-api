FROM postman/newman:alpine

ENV API_URL=http://localhost:3000/

WORKDIR /etc/newman

COPY vets-api.pm-collection.json vets-api.pm-collection.json

ENTRYPOINT newman run vets-api.pm-collection.json -x --env-var envUnderTest=$API_URL
