#!/bin/sh

# this runs as part of pre-build

echo "on-create start"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create start" >> "$HOME/status"

# Homebrew/asdf paths to zsh
{
  echo "export PATH=\"/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:\$PATH\""
  echo "source \"\$HOME/.asdf/asdf.sh\""
} >> ~/.zshrc

export PATH="${HOME}/.asdf/shims:${HOME}/.asdf/bin:${PATH}"
asdf install ruby $( cat .ruby-version )
asdf global ruby $( cat .ruby-version )

# Clone needed repos
git clone https://github.com/department-of-veterans-affairs/vets-api-mockdata.git /workspaces/vets-api-mockdata

# Install dependencies
sudo apt-get update
sudo apt-get install -y libpq-dev pdftk shared-mime-info postgresql-15-postgis-3 tmux xclip

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
mkdir -p log
nohup bash -c '/home/linuxbrew/.linuxbrew/opt/redis@6.2/bin/redis-server /home/linuxbrew/.linuxbrew/etc/redis.conf' >> log/redis.log 2>&1 &

# Start postgres
sudo /etc/init.d/postgresql restart
pg_isready -t 60
sudo -u root sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'password';"

# Install gems and setup DB
./bin/setup

# Prewarm Bootsnap
bundle exec bootsnap precompile --gemfile app/ lib/

echo "on-create complete"
echo "$(date +'%Y-%m-%d %H:%M:%S')    on-create complete" >> "$HOME/status"
