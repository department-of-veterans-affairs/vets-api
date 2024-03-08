#!/bin/sh

# Switch to vets-api ruby version
asdf install ruby $( cat .ruby-version )
asdf global ruby $( cat .ruby-version )

sudo apt update
sudo apt install -y libpq-dev pdftk shared-mime-info

gem install bundler
bundle install

docker-compose -f docker-compose-deps.yml build

# Add hybrid service config
if [ ! -f config/settings.local.yml ]; then
  cp config/settings.local.yml.example config/settings.local.yml
  cat <<EOT >> config/settings.local.yml
database_url: postgis://postgres:password@localhost:54320/vets_api_development?pool=4
test_database_url: postgis://postgres:password@localhost:54320/vets_api_test?pool=4

redis:
host: localhost
port: 63790
app_data:
    url: redis://localhost:63790
sidekiq:
    url: redis://localhost:63790
EOT
fi
