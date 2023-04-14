# Developer Setup

Vets API requires:

- Ruby 3.2.2
- PostgreSQL 11.x (including PostGIS 2.5)
- Redis 5.0.x

  The most up-to-date versions of each key dependency will be specified in the `docker-compose.yml` [file](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docker-compose.yml) and the `Dockerfile`.

  We suggest using a Ruby version manager such as [`rbenv`](https://github.com/rbenv/rbenv#installation), `asdf`, `rvm`, or `chruby` to install and maintain your version of Ruby.

## Installing RVM

1. Install `rvm` with `brew install rvm`. This could take a while.
2. Check the ruby version number in `.ruby-version`. Use this number to install the needed Ruby version in the command `rvm install <version_number>`. This could also take a while.
3. Run `rvm use` within the repo to confirm that the correct version is being used.
4. After installing a new version of Ruby, run `gem install bundler` and `bundle install` to ensure all gems are installed for the current version.

Steps 2-4 must be repeated if the repo's Ruby version is updated later.

## Base Setup

1. Follow the common [base setup](https://github.com/department-of-veterans-affairs/vets-api/blob/master/README.md#Base%20setup).

1. Install Bundler to manage Ruby dependencies

   ```bash
   gem install bundler
   ```

1. Follow the platform specific notes below for [OSX](#osx) or [Ubuntu](#alternative-ubuntu-2004-lts) to get dependencies installed.

1. Install gem dependencies:

   ```bash
   cd vets-api; bundle install
   ```

   More information about installing _with_ Sidekiq Enterprise as well as our credentials are on the internal system [here](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Platform/Vets-API/Sidekiq%20Enterprise%20Setup.md)

1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed, preferably in a sibling directory to `vets-api`.

1. Go to the file `config/settings/development.yml` and make sure the `cache-dir` points to the local installation of `vets-api-mockdata` from the previous step.

   ```yaml
   cache_dir: ../vets-api-mockdata # via rails; e.g. bundle exec rails s or bundle exec rails c
   # cache_dir: /cache # via docker; e.g. make up or make console
   ```

1. Add this key in `config/settings.local.yml` pointing to your `vets-api-mockdata` directory.

   ```yaml
   # settings.local.yml
   betamocks:
     cache_dir: ../vets-api-mockdata
   ```

1. Run `bin/setup` to setup the database and start the server.

### pg_stat_statements
If you have trouble enabling query stats from the PgHero dashboard, try enabling it manually

Add the lines below to your main postgresql.conf file

On Mac it should be located somewhere similiar to the following:

`~/Library/Application Support/Postgres/var-12/postgresql.conf`
```
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
track_activity_query_size = 2048
```

**Make sure to migrate your database to enable the [pg_stat_statements extension](https://github.com/department-of-veterans-affairs/vets-api/blob/master/db/migrate/20210507122840_add_stats_extension.rb)**

## Settings and configuration

We use the `config` gem to manage settings in the application. Local settings for each developer should be managed in your own local `config/settings.local.yml` file, which by default can override the standard configuration _and_ is excluded from source control so the settings can persist.

This file has the necessary configuration settings for local development as well as comments outlining some additional configuration that some developers may wish to use.

### Configuring ClamAV antivirus

### EKS

Prior to EKS, ClamAV (the virus scanner) was deployed in the same process as Vets API. With EKS, ClamAV has been extracted out into it’s own service. Locally you can see the docker-compose.yml config for clamav.

**TODO**: Running clamav natively, as we did in Vets API master still needs to be configured. For the time being, **please run via docker**:

Please set the [clamav intitalizer](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/config/initializers/clamav.rb) initializers/clamav.rb file to the following:

``` 
# ## If running hybrid
if Rails.env.development?
   ENV["CLAMD_TCP_HOST"] = "0.0.0.0"
   ENV["CLAMD_TCP_PORT"] = "33100"
 end
```

### Options
#### Option 1: Run ONLY clamav via Docker

You can either run:
`docker-compose -f docker-compose-clamav.yml up` - this will run ONLY clamav via docker

After that, follow the native instructions and run `foreman start -m all=1`

#### Option 2: [See hybrid setup](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/docs/setup/hybrid.md)

<!-- 
In many cases, there in no need to run ClamAV for local development, even if you are working with uploaded files since the scanning functionality is already built into our CarrierWave and Shrine file upload base classes.

If you would like to run a fake ClamAV "scanner" that will quickly produce a virus-free scan, you can configure the application to use the executable bash script `bin/fake_clamd`. This configuration is commented out in `config/settings.local.yml`

```yaml
binaries:
  # For NATIVE and DOCKER installation
  # A "virus scanner" that always returns success for development purposes
  # NOTE: You may need to specify a full path instead of a relative path
  clamdscan: ./bin/fake_clamdscan
``` -->

If you wish to run ClamAV, you'll need to check the platform specific notes.

## Platform Specific Notes

Specific notes for our most common native installation platforms are in this section. Note that most Windows users tend to use Docker instead of a native installation.

### OSX

All of the OSX instructions assume `homebrew` is your [package manager](https://brew.sh/)

1. Install Postgresql & PostGIS

   1. It is MUCH easier to use the [Postgres.app](https://postgresapp.com/downloads.html) which installs the correct combination of Postgresql and PostGIS versions.

   - Download the Postgres.app with PostgreSQL 10, 11 and 12
   - Install Instructions here: https://postgresapp.com/
   - `sudo mkdir -p /etc/paths.d && echo /Applications/Postgres.app/Contents/Versions/latest/bin | sudo tee /etc/paths.d/postgresapp`
   - `ARCHFLAGS="-arch x86_64" gem install pg -v 1.2.3`
   2. Alternatively Postgresql 11 & PostGIS 2.5 can be installed with homebrew
      - `brew install postgresql@11`
      - `brew services start postgresql@11`
      - Install the `pex` manager to add your Postgresql 11 extensions from [here](https://github.com/petere/pex#installation)
      - Install the `postgis` extension along with a number of patches using the instructions summarized [here](https://gist.github.com/skissane/0487c097872a7f6d0dcc9bcd120c2ccd):
      - ```bash
         PG_CPPFLAGS='-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include' CFLAGS='-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include' pex install postgis
        ```
   - run postgres (e.g. open postgres.app, create a new server, and click "initialize")

2. Install redis
    ```bash
    brew install redis
    brew services start redis
    ```


3. Install binary dependencies:
    ```bash
    brew bundle
    ```

4. Among other things, the above `brew bundle` command installs ClamAV, but does not enable it. To enable ClamAV:

   ```bash
   brew info clamav
   # See the "Caveats" section: "To finish installation & run clamav you will need to edit the example conf files at `${conf_files_dir}`"
   cd $(brew --prefix clamav)
   touch clamd.sock
   echo "LocalSocket $(brew --prefix clamav)" > clamd.conf
   echo "DatabaseMirror database.clamav.net" > freshclam.conf
   # Update the local ClamAV database
   freshclam -v
   ```

   NOTE: Run with `/usr/local/sbin/clamd -c /usr/local/etc/clamav/clamd.conf` and you will also have to override (temporarily) the `config/clamd.conf` file with `-LocalSocket /usr/local/etc/clamav/clamd.sock`

5. Install [pdftk](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg)

   - `curl -o ~/Downloads/pdftk_download.pkg https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg`
   - `sudo installer -pkg ~/Downloads/pdftk_download.pkg -target /`

6. continue with [Base setup](native.md#base-setup)

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
   - `sudo apt install -y poppler-utils`
1. Install ClamAV
   - `sudo apt install -y clamav`
1. Install pdftk
   - `sudo apt install -y pdftk`
1. continue with [Base setup](native.md#base-setup)
