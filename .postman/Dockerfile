FROM postman/newman:alpine

WORKDIR /etc/newman

COPY postman_collection.json postman_collection.json

CMD ["newman", "run", "postman_collection.json", "--env-var 'targetClusterAddress=$clusterUnderTest'"]