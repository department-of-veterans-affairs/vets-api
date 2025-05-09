#!/bin/sh

# this runs as part of pre-build

echo "on-create start"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create start" >> "$HOME/status"

# Homebrew/asdf paths to zsh
{
  echo "source \"\$HOME/.asdf/asdf.sh\""
} >> ~/.zshrc

export PATH="${HOME}/.asdf/shims:${HOME}/.asdf/bin:${PATH}"
asdf install ruby $( cat .ruby-version )
asdf global ruby $( cat .ruby-version )

# Clone needed repos and set permission to the dev-container user
sudo mkdir -p /workspaces/vets-api-mockdata
sudo chown $(whoami):$(whoami) /workspaces/vets-api-mockdata
git clone https://github.com/department-of-veterans-affairs/vets-api-mockdata.git /workspaces/vets-api-mockdata

# Install dependencies
sudo apt-get update

# Add Redis repository for version 6.2
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt-get update
sudo apt-get install -y redis-tools=6:6.2* redis-server=6:6.2*

# Install other dependencies
sudo apt-get install -y libpq-dev pdftk shared-mime-info postgresql-15-postgis-3 tmux xclip

# Configure and start Redis
sudo sed -i 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis/redis.conf
sudo sed -i 's/protected-mode yes/protected-mode no/g' /etc/redis/redis.conf

# only run apt upgrade on pre-build
if [ "$CODESPACE_NAME" = "null" ]
then
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y
    sudo apt-get clean -y
fi

gem install bundler
NUM_CORES=$( cat /proc/cpuinfo | grep '^processor'|wc -l )
bundle config --global jobs `expr $NUM_CORES - 1`

# Update test DB config
echo 'test_database_url: postgis://postgres:password@localhost:5432/vets_api_test?pool=4' > config/settings/test.local.yml

# Add service config
if [ ! -f config/settings.local.yml ]; then
  cp config/settings.local.yml.example config/settings.local.yml
  cat <<EOT >> config/settings.local.yml
database_url: postgis://postgres:password@localhost:5432/vets_api_development?pool=4
test_database_url: postgis://postgres:password@localhost:5432/vets_api_test?pool=4
audit_db:
  url: postgis://postgres:password@localhost:5432/vets_api_audit

redis:
  host: localhost
  port: 6379
  app_data:
    url: redis://localhost:6379
  sidekiq:
    url: redis://localhost:6379

betamocks:
  cache_dir: ../vets-api-mockdata

# Allow access from localhost and shared github URLs.
virtual_hosts: ["127.0.0.1", "localhost", !ruby/regexp /.*\.app\.github\.dev/]
EOT
fi

# Start redis

sudo /etc/init.d/redis-server restart

# Start postgres
sudo /etc/init.d/postgresql restart
pg_isready -t 60
sudo -u root sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'password';"

# Install gems and setup DB
bundle install
rails db:setup

# Prewarm Bootsnap
bundle exec bootsnap precompile --gemfile app/ lib/

echo "on-create complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create complete" >> "$HOME/status"
