#!/bin/sh

# Switch to vets-api ruby version
asdf install ruby $( cat .ruby-version )
asdf global ruby $( cat .ruby-version )

git clone https://github.com/department-of-veterans-affairs/vets-api-mockdata.git ../vets-api-mockdata

sudo apt update
sudo apt install -y libpq-dev pdftk shared-mime-info postgresql-client

gem install bundler
bundle install

# Set up postgres + redis.
docker-compose -f docker-compose-deps.yml build

# Update default test DB config (because this config overrides the local settings when running tests)
sed -i 's|^test_database_url: .*$|test_database_url: postgis://postgres:password@localhost:54320/vets_api_test?pool=4|' config/settings.yml

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

betamocks:
  cache_dir: ../vets-api-mockdata
EOT
fi
