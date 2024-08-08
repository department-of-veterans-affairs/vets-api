FROM postman/newman:alpine

ENV API_URL=http://localhost:3000/

WORKDIR /etc/newman

COPY postman_collection.json postman_collection.json

ENTRYPOINT ["newman", "run", "postman_collection.json", "--env-var", "'targetClusterAddress=$API_URL'"]