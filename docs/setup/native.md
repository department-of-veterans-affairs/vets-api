## Developer Setup

Vets API requires:

- PostgreSQL
  - Including PostGIS
- Redis
- Ruby 2.6.6

### Base Setup

To start, fetch this code:

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`

#### Automated (OSX)

If you are developing on OSX, you can run the automated setup script. From the `vets-api` directory, run `./bin/setup-osx && source ~/.bash_profile && cd .`

---

**NOTE**

This installs rbenv and other homebrew libraries for this project. If you only want to manage your own libraries, it is suggested you continue below.

---

#### Alternative (OSX)

1. Install Ruby 2.6.6
   - It is suggested that you use a Ruby version manager such as
     [rbenv](https://github.com/rbenv/rbenv#installation) and
     [install Ruby 2.6.6](https://github.com/rbenv/rbenv#installing-ruby-versions).
   - _NOTE_: rbenv will also provide additional installation instructions in the
     console output. Make sure to follow those too.
1. Install Bundler to manage dependencies
   - `gem install bundler`
1. Install Postgres and enable on startup
   ```bash
   brew install postgres
   brew services start postgres
   ```
1. Install PostGIS
   - `brew install postgis`
1. Install Redis
   - `brew install redis`
   - Follow post-install instructions to enable Redis on startup. Otherwise,
     launch it manually with `brew services start redis`.
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
1. Install [pdftk](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg)
   - `curl -o ~/Downloads/pdftk_download.pkg https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg`
   - `sudo installer -pkg ~/Downloads/pdftk_download.pkg -target /`
1. Install gem dependencies:
   - `cd vets-api; bundle install`
     - If you receive an error installing nokogiri, you may need to tell bundle to build with local libraries: `bundle config build.nokogiri --use-system-libraries`
   - More information about installing _with_ Sidekiq Enterprise as well as our credentials are on the internal system here: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Platform/Vets-API/Sidekiq%20Enterprise%20Setup.md
1. Install overcommit `overcommit --install --sign`
1. Create dev database: `bundle exec rake db:setup`
1. Go to the file `config/settings/development.yml` in your local vets-api. Toggle commenting so that the native method is uncommented only.
   ```yaml
   cache_dir: ../vets-api-mockdata # via rails; e.g. bundle exec rails s or bundle exec rails c
   # cache_dir: /cache # via docker; e.g. make up or make console
   ```
1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed, preferably in a parallel directory to `vets-api`.
1. Create a `config/settings.local.yml` file for your local configuration overrides. Add this key pointing to your `vets-api-mockdata` directory.
   ```yaml
   betamocks:
     cache_dir: ../vets-api-mockdata
   ```

#### Ubuntu 20.04 LTS

1. Install Ruby 2.6.6
   - It is suggested that you use a Ruby version manager such as
     [rbenv](https://github.com/rbenv/rbenv#basic-github-checkout) and
     [install Ruby 2.6.6](https://github.com/rbenv/rbenv#installing-ruby-versions).
   - _NOTE_: rbenv will also provide additional installation instructions in the
     console output. Make sure to follow those too.
   - `rbenv install 2.6.6` may require you to install dependencies, follow the instructions in the console output.
1. Install Bundler to manage dependencies
   - `gem install bundler`
1. Install Postgres and enable on startup
   ```bash
   sudo apt install -b postgresql postgresql-contrib libpq-dev
   sudo systemctl start postgresql@12-main

   sudo -i -u postgres
   createuser --superuser bam
   exit
   ```
1. Install PostGIS
   ```bash
   sudo apt install -y postgis postgresql-12-postgis-3
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
1. Install gem dependencies:
   - `cd vets-api; bundle install`
   - More information about installing _with_ Sidekiq Enterprise as well as our credentials are on the internal system here: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Platform/Vets-API/Sidekiq%20Enterprise%20Setup.md
1. Install overcommit `overcommit --install --sign`
1. Go to the file `config/settings/development.yml` in your local vets-api. Toggle commenting so that the native method is uncommented only.
   ```yaml
   cache_dir: ../vets-api-mockdata # via rails; e.g. bundle exec rails s or bundle exec rails c
   # cache_dir: /cache # via docker; e.g. make up or make console
   ```
1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed, preferably in a parallel directory to `vets-api`.
1. Create a `config/settings.local.yml` file for your local configuration overrides. Add this key pointing to your `vets-api-mockdata` directory.
   ```yaml
   betamocks:
     cache_dir: ../vets-api-mockdata
   ```
1. Setup key & cert for localhost authentication to ID.me:
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
1. Create dev database: `bundle exec rake db:setup`
1. Startup server: `bundle exec rails s`

#### Alternative (Ubuntu 18.04 LTS)

1. Install Postgres, PostGIS, Redis, ImageMagick, Poppler, ClamAV, etc
   - From the `vets-api` directory, run `./bin/install-ubuntu-packages`
1. Edit `/etc/ImageMagick-6/policy.xml` and remove the lines below the comment `<!-- disable ghostscript format types -->`
   - This may not be necessary. The default policy was updated to [fix a variety of vulnerabilities](https://usn.ubuntu.com/3785-1/) as of October, 2018.
1. Install Ruby 2.4.5
   - It is suggested that you use a Ruby version manager such as
     [rbenv](https://github.com/rbenv/rbenv#installation) and
     [install Ruby 2.4.5](https://github.com/rbenv/rbenv#installing-ruby-versions).
   - _NOTE_: rbenv will also provide additional installation instructions in the
     console output. Make sure to follow those too.
1. Install Bundler to manage dependencies
   - `gem install bundler`
1. Install gem dependencies: `cd vets-api; bundle install`
1. Install overcommit `overcommit --install --sign`
1. Setup localhost certificates / keys:
   - Create certs directory within config: `mkdir ./config/certs`
   - Copy [these certificates](https://github.com/department-of-veterans-affairs/vets.gov-team/tree/master/Products/Identity/Files_From_IDme/development-certificates) into the certs dir.
     - _NOTE_: If you don't have access to these keys, running the following
       commands will provide basic functionality, such as for running unit tests:
     - `touch ./config/certs/vetsgov-localhost.crt`
     - `touch ./config/certs/vetsgov-localhost.key`
1. Create dev database: `bundle exec rake db:setup`
1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed, preferably in a parallel directory to `vets-api`.
1. Create a `config/settings.local.yml` file for your local configuration overrides. Add this key pointing to your `vets-api-mockdata` directory.

```
betamocks:
  cache_dir: ../vets-api-mockdata
```
