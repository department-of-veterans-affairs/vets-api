#!/bin/sh

echo "Ensuring ruby is up to date..."
export PATH="${HOME}/.asdf/shims:${HOME}/.asdf/bin:${PATH}"
asdf plugin update ruby
asdf install ruby $( cat .ruby-version )
asdf global ruby $( cat .ruby-version )

echo "Ensuring packages are up to date..."
bundle install

echo "Starting Redis ..."
sudo /etc/init.d/redis-server restart

echo "Starting postgres..."
sudo /etc/init.d/postgresql restart
echo "Waiting for postgres to be ready..."
pg_isready -t 60
