# Developer Setup

Vets API requires:

- Ruby 3.2.3
- PostgreSQL 15.x (including PostGIS 3)
- Redis 6.2.x

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

1. Setup local databases and run schema migrations:
   ```bash
   cd vets-api; rails db:setup; rails db:migrate
   ```

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

In many cases, there in no need to run ClamAV for local development, even if you are working with uploaded files since the scanning functionality is already built into our CarrierWave and Shrine file upload base classes.

If you would like to run a fake ClamAV "scanner" that will quickly produce a virus-free scan, you can configure the application to use the executable bash script `bin/fake_clamd`. This configuration is commented out in `config/settings.local.yml`

```yaml
binaries:
  # For NATIVE and DOCKER installation
  # A "virus scanner" that always returns success for development purposes
  # NOTE: You may need to specify a full path instead of a relative path
  clamdscan: ./bin/fake_clamdscan
```

If you wish to run ClamAV, you'll need to check the platform specific notes.

## Platform Specific Notes

Specific notes for our most common native installation platforms are in this section. Note that most Windows users tend to use Docker instead of a native installation.

### OSX

All of the OSX instructions assume `homebrew` is your [package manager](https://brew.sh/)

1. Install Postgresql & PostGIS

   1. It is MUCH easier to use the [Postgres.app](https://postgresapp.com/downloads.html) which installs the correct combination of Postgresql and PostGIS versions.

   - Download the Postgres.app with PostgreSQL 15
   - Install Instructions here: https://postgresapp.com/
   - `sudo mkdir -p /etc/paths.d && echo /Applications/Postgres.app/Contents/Versions/latest/bin | sudo tee /etc/paths.d/postgresapp`
   - `ARCHFLAGS="-arch x86_64" gem install pg -v 1.2.3`
   2. Alternatively Postgresql 15 & PostGIS 3 can be installed with homebrew
      - `brew install postgresql@15`
      - `brew services start postgresql@15`
      - Install the `pex` manager to add your Postgresql 15 extensions from [here](https://github.com/petere/pex#installation)
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

2. Install PostGIS

   ```bash
   sudo apt install -y postgresql-15-postgis-3
   sudo -i -u postgres

   createuser postgis_test
   createdb postgis_db -O postgis_test
   psql -d postgis_db

   CREATE EXTENSION postgis;
   SELECT PostGIS_version();
   \q
   ```

3. Install Redis
   ```bash
   sudo apt install -y redis-server
   sudo sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
   sudo systemctl restart redis.service
   sudo systemctl status redis # ctrl+c to exit
   ```
4. Install ImageMagick
   - `sudo apt install -y imagemagick`
5. Install Poppler
   - `sudo apt install -y poppler-utils`
6. Install ClamAV
   - `sudo apt install -y clamav`
7. Install pdftk
   - `sudo apt install -y pdftk`
8. continue with [Base setup](native.md#base-setup)

9. Updating Postgres and PostGIS if you already have them installed

   Backup your existing database
   ```bash
   sudo su -
   cd /home
   mkdir postgres
   chown postgres: postgres
   exit
   sudo su - postgres
   cd /home/postgres
   pg_dumpall > backup.sql
   ```

   Backup your configuration files (replace hashes with the db vsn eg 11)
   ```bash
   cp /etc/postgresql/##/main/pg_hba.conf .
   cp /etc/postgresql/##/main/postgresql.conf .
   ```


   Remove any unwanted versions (replace hashes with the db vsn eg 11)
   ```bash
   dpkg -l | grep postgres
   sudo apt --purge remove postgresql-## postgresql-client-##

      repeat the above command for each unwanted version

   sudo apt autoremove
   ```

   Upgrade any packages that need to be updated
   ```bash
   sudo apt update
   sudo apt upgrade
   ```

   Upgrade the database (replace hashes with the new db vsn eg 14)
   ```bash
   sudo apt install postgresql-## postgresql-server-dev-##


   Very important! the upgrade will fail later if you don't install postgis in the updated postgresql

     replace the hash symbols with the database version eg 14
     replace the n with the postgis version eg 3

   sudo apt install postgresql-##-postgis-n
   sudo apt install postgresql-##-postgis-n-scripts
   ```

   List all installed versions (again)
   ```bash
   dpkg -l | grep postgres

     you should see the current version and the version you just installed
   ```
   Stop the postgresql service
   ```bash
   sudo systemctl stop postgresql.service

     Check the status of the postgresql, it should be stopped
   systemctl status postgresql.service

     The install sets up a cluster, which needs then to be removed for the upgrade.
     replace the hashes with the UPDATED version eg 14
   sudo pg_dropcluster ## main --stop

     replace the hashes with the CURRENT version eg 11
   sudo pg_upgradecluster ## main

     At the end, you should see this with current version red and updated version green:
     Example 11 and 14
     =====
      Success. Please check that the upgraded cluster works. If it does,
      you can remove the old cluster with
          pg_dropcluster 11 main

      Ver Cluster Port Status Owner    Data directory              Log file
      11  main    5433 down   postgres /var/lib/postgresql/11/main /var/log/postgresql/postgresql-11-main.log
      Ver Cluster Port Status Owner    Data directory              Log file
      14  main    5432 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
      =====

     Check the status of postgresql (it should be running)
   systemctl status postgresql.service

     Check the processes of postgresql running, you should see the upgraded version in the processes running
   ps -efa | grep postgres

     Check the port postgresql is running on, it should be 5432 unless you customized it
   sudo netstat -anp | grep 543

     Login to the postgres user and check the version
   sudo su postgres
   psql -c "SELECT version();"

     You should see the version you upgraded to

   exit

     Remove the old cluster

     replace hashes with the CURRENT version eg 11
   sudo pg_dropcluster ## main

   Done!!!
  ```
