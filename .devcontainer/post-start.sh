#!/bin/sh

echo "Ensuring ruby is up to date..."
asdf install ruby $( cat .ruby-version )
asdf global ruby $( cat .ruby-version )

echo "Starting redis..."
nohup /home/linuxbrew/.linuxbrew/opt/redis@6.2/bin/redis-server /home/linuxbrew/.linuxbrew/etc/redis.conf >> log/redis.log 2>&1 &

echo "Starting postgres..."
sudo /etc/init.d/postgresql restart
echo "Waiting for postgres to be ready..."
pg_isready -t 60
