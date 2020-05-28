# Developer Setup

Vets API requires:

- Ruby 2.6.6
- PostgreSQL 11.x (including PostGIS 2.5)
- Redis 5.0.x

   The most up-to-date versions of each key dependency will be specified in the `docker-compose.yml` [file](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docker-compose.yml) and the `Dockerfile`.

   We suggest using a Ruby version manager such as `rbenv`, `asdf`, `rvm`, or `chruby` to install and maintain your version of Ruby.


## Base Setup

To start, fetch this code:

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`

1. Install Bundler to manage dependencies
   - `gem install bundler`
1. Follow the platform specific notes below for OSX or Ubuntu to get dependencies installed.
1. Install gem dependencies:
   - `cd vets-api; bundle install`
   - More information about installing _with_ Sidekiq Enterprise as well as our credentials are on the internal system [here](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Platform/Vets-API/Sidekiq%20Enterprise%20Setup.md)
1. Install overcommit `overcommit --install --sign`
1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed, preferably in a parallel directory to `vets-api`.
1.  Go to the file `config/settings/development.yml` and make sure the `cache-dir` points to the local installation of `vets-api-mockdata` from the previous step.
   ```yaml
   cache_dir: ../vets-api-mockdata # via rails; e.g. bundle exec rails s or bundle exec rails c
   # cache_dir: /cache # via docker; e.g. make up or make console
   ```
1. Create a `config/settings.local.yml` file for your local configuration overrides. Add this key pointing to your `vets-api-mockdata` directory.
   ```yaml
   betamocks:
     cache_dir: ../vets-api-mockdata
   ```
1.  Setup key & cert for localhost authentication to ID.me:
   ```bash
   mkdir config/certs
   touch config/certs/vetsgov-localhost.crt
   touch config/certs/vetsgov-localhost.key
   ```
1. Disable signed authentication requests:
   ```yaml
   # settings.local.yml
   saml:
     authn_requests_signed: false
   ```
1. Run `bin/setup` to setup the database and start the server.


## Platform Specific Notes

Specific notes for our most common native installation platforms are in this section. Note that most Windows users tend to use Docker instead of a native installation.

### OSX

All of the OSX instructions assume `homebrew` is your [package manager](https://brew.sh/)

1. Postgresql 11 can be installed
   `brew install postgresql@11`
1. Install Redis
   - `brew install redis`
1. Install PostGIS 2.5
   - `brew services start postgresql@11`
   - Install the `pex` manager to add your Postgresql 11 extensions from [here](https://github.com/petere/pex#installation)
   - Install the `postgis` extension along with a number of patches using the instructions summarized [here](https://gist.github.com/skissane/0487c097872a7f6d0dcc9bcd120c2ccd):
   - ```bash
      PG_CPPFLAGS='-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include' CFLAGS='-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include' pex install postgis

   It may be MUCH easier to use the Postgres.app which makes installing the correct combination of Postgresql and PostGIS versions.
1. Install ImageMagick
   - `brew install imagemagick`
1. Install Poppler
   - `brew install poppler`
1. Install ClamAV
   ```bash
   brew install clamav # Take note of the the post-install instructions "To finish installation & run clamav you will need to edit the example conf files at `${conf_files_dir}`", which will vary depending on your homebrew installation
   cd ${conf_files_dir}
   touch clamd.sock
   echo "LocalSocket ${conf_files_dir}" > clamd.conf
   echo "DatabaseMirror database.clamav.net" > freshclam.conf
   freshclam -v
   ```
5. Install [pdftk](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg)
   - `curl -o ~/Downloads/pdftk_download.pkg https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg`
   - `sudo installer -pkg ~/Downloads/pdftk_download.pkg -target /`

### Alternative (Ubuntu 20.04 LTS)

1. Install Postgres and enable on startup
   ```bash
   wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
   echo "deb http://apt.postgresql.org/pub/repos/apt/ focal"-pgdg main | sudo tee  /etc/apt/sources.list.d/pgdg.list
   sudo apt update
   sudo apt install postgresql-11
   sudo systemctl start postgresql

   sudo -i -u postgres
   createuser --superuser YOURNAME
   exit
   ```
1. Install PostGIS
   ```bash
   sudo apt install -y postgresql-11-postgis-2.5
   sudo -i -u postgres

   createuser postgis_test
   createdb postgis_db -O postgis_test
   psql -d postgis_db

   CREATE EXTENSION postgis;
   SELECT PostGIS_version();
   \q
   ```
1. Install Redis
   ```bash
   sudo apt install -y redis-server
   sudo sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
   sudo systemctl restart redis.service
   sudo systemctl status redis # ctrl+c to exit
   ```
1. Install ImageMagick
   - `sudo apt install -y imagemagick`
1. Install Poppler
   - `sudo apt install -y poppler-utils
1. Install ClamAV
   - `sudo apt install -y clamav`
1. Install pdftk
   - `sudo apt install -y pdftk`
