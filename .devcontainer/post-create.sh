#!/bin/sh

# Add welcome message
sudo cp .devcontainer/welcome.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt

git clone https://github.com/department-of-veterans-affairs/vets-api-mockdata.git ../vets-api-mockdata

sudo apt update
sudo apt install -y libpq-dev pdftk shared-mime-info postgresql-11-postgis-3

gem install bundler
NUM_CORES=$( cat /proc/cpuinfo | grep '^processor'|wc -l )
bundle config --global jobs `expr $NUM_CORES - 1`

# Update default test DB config (because this config overrides the local settings when running tests)
# FIXME: necessary?
# sed -i 's|^test_database_url: .*$|test_database_url: postgis://postgres:password@localhost:54320/vets_api_test?pool=4|' config/settings.yml

# Add service config
if [ ! -f config/settings.local.yml ]; then
  cp config/settings.local.yml.example config/settings.local.yml
  cat <<EOT >> config/settings.local.yml
database_url: postgis://postgres:password@localhost:5432/vets_api_development?pool=4
test_database_url: postgis://postgres:password@localhost:5432/vets_api_test?pool=4

redis:
  host: localhost
  port: 6379
  app_data:
    url: redis://localhost:6379
  sidekiq:
    url: redis://localhost:6379

betamocks:
  cache_dir: ../vets-api-mockdata
EOT
fi

mkdir -p log
sudo /etc/init.d/postgresql restart
pg_isready -t 60
sudo -u root sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'password';"
./bin/setup
