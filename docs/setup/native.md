## Native Setup

If you can run docker, use the [Base Setup](/README.md#base-setup) instructions. Reach out to the #devops slack channel if you need to use these.

## Developer Setup

Vets API requires:
- PostgreSQL
    - Including PostGIS
- Redis
- Ruby 2.4.5

### Base Setup

To start, fetch this code:

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`


#### Automated (OSX)

If you are developing on OSX, you can run the automated setup script. From
the `vets-api` directory, run `./bin/setup-osx && source ~/.bash_profile && cd
.`

#### Alternative (OSX)

1. Install Ruby 2.4.5
   - It is suggested that you use a Ruby version manager such as
    [rbenv](https://github.com/rbenv/rbenv#installation) and
    [install Ruby 2.4.5](https://github.com/rbenv/rbenv#installing-ruby-versions).
   - *NOTE*: rbenv will also provide additional installation instructions in the
    console output. Make sure to follow those too.
1. Install Bundler to manage dependencies
   - `gem install bundler`
1. Install Postgres and enable on startup
   - `brew install postgres`
   - `brew services start postgres`
1. Install PostGIS
   - `brew install postgis`
1. Install Redis
   - `brew install redis`
   - Follow post-install instructions to enable Redis on startup. Otherwise,
    launch it manually with `brew services start redis`.
1. Install ImageMagick
   - `brew install imagemagick`
1. Install Poppler
   -  `brew install poppler`
1. Install ClamAV
   - `brew install clamav`
   - Take note of the the post-install instructions `To finish installation & run
    clamav
  you will need to edit the example conf files at ${conf_files_dir}`
(_${conf_files_dir}_ 
  will differ based on your homebrew location) then:
    - `cd ${conf_files_dir}`
    - `touch clamd.sock`
    - `echo "LocalSocket ${conf_files_dir}" > clamd.conf` 
    - `echo "DatabaseMirror database.clamav.net" > freshclam.conf`
    - `freshclam -v`
1. Install [pdftk](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg)
1. Install gem dependencies: `cd vets-api; bundle install`
1. Install overcommit `overcommit --install --sign`
1. Setup localhost certificates / keys:
   - Create certs directory within config:  `mkdir ./config/certs`
   - *NOTE*: If you don't have access to these keys, [Create your own self-signed certificate](https://github.com/department-of-veterans-affairs/vets.gov-team/tree/master/Products/Identity/Login/IDme/development-certificates#creating-your-own-self-signed-certificates)
   - Copy the [certificate](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Login/IDme/development-certificates/vetsgov-localhost.crt) to `./config/certs/vetsgov-localhost.crt`
   - Copy the [key](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Login/IDme/development-certificates/vetsgov-localhost.key) to `./config/certs/vetsgov-localhost.key`

1. Create dev database: `bundle exec rake db:setup`
1. Create `config/settings.local.yml` in your local vets-api with:
````
betamocks:
  # the cache dir depends on how you run the api, run `bin/spring stop` after switching this setting
  cache_dir: ../vets-api-mockdata # native
  # cache_dir: /cache #use this if using docker
````
1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed

#### Alternative (Ubuntu 18.04 LTS)
1. Install Postgres, PostGIS, Redis, ImageMagick, Poppler, ClamAV, etc
   - From the `vets-api` directory, run `./bin/install-ubuntu-packages`
1. Edit `/etc/ImageMagick-6/policy.xml` and remove the lines below the comment `<!-- disable ghostscript format types -->`
   - This may not be necessary. The default policy was updated to [fix a variety of vulnerabilities](https://usn.ubuntu.com/3785-1/) as of October, 2018.
1. Install Ruby 2.4.5
   - It is suggested that you use a Ruby version manager such as
    [rbenv](https://github.com/rbenv/rbenv#installation) and
    [install Ruby 2.4.5](https://github.com/rbenv/rbenv#installing-ruby-versions).
   - *NOTE*: rbenv will also provide additional installation instructions in the
    console output. Make sure to follow those too.
1. Install Bundler to manage dependencies
   - `gem install bundler`
1. Install gem dependencies: `cd vets-api; bundle install`
1. Install overcommit `overcommit --install --sign`
1. Setup localhost certificates / keys:
   - Create certs directory within config:  `mkdir ./config/certs`
   - Copy [these certificates](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/Login/IDme/development-certificates) into the certs dir.
1. Create dev database: `bundle exec rake db:setup`
1. Create `config/settings.local.yml` in your local vets-api with:
````
betamocks:
  # the cache dir depends on how you run the api, run `bin/spring stop` after switching this setting
  cache_dir: ../vets-api-mockdata # native
  # cache_dir: /cache #use this if using docker
````
1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed


