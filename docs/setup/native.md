## Native Setup

If you can run docker, use the [Base Setup](/README.md#base-setup) instructions. Reach out to the #devops slack channel if you need to use these.

## Developer Setup

Vets API requires:
- PostgreSQL
    - Including PostGIS
- Redis
- Ruby 2.3

### Base Setup

To start, fetch this code:

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`


#### Automated (OSX)

If you are developing on OSX, you can run the automated setup script. From
the `vets-api` directory, run `./bin/setup-osx && source ~/.bash_profile && cd
.`

#### Alternative (OSX)

1. Install Ruby 2.3.
   - It is suggested that you use a Ruby version manager such as
    [rbenv](https://github.com/rbenv/rbenv#installation) and
    [install Ruby 2.3](https://github.com/rbenv/rbenv#installing-ruby-versions).
   - *NOTE*: rbenv will also provide additional installation instructions in the
    console output. Make sure to follow those too.
1. Install Bundler to manage dependencies
   - `gem install bundler`
1. Install Postgres and enable on startup
   - `brew install postgres`
   - `brew services start postgres`
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
1. Install pdftk
  - `brew install
    https://gist.githubusercontent.com/lihanli/03ec8f17a6a1ff52e3a149be4cf7f2ae/raw/d18eff01396bbc25a928f756ff21edcc3521fc5e/pdftk.rb`
1. Install gem dependencies: `cd vets-api; bundle install`
1. Install overcommit `overcommit --install --sign`
1. Setup localhost certificates / keys:
   - Create certs directory within config:  `mkdir ./config/certs`
   - Copy the [certificate][certificate] to `./config/certs/vetsgov-localhost.crt`
   - Copy the [key][key] to `./config/certs/vetsgov-localhost.key`
   - *NOTE*: If you don't have access to these keys, running the following
     commands will provide basic functionality, such as for running unit tests:
   - `touch ./config/certs/vetsgov-localhost.crt`
   - `touch ./config/certs/vetsgov-localhost.key`
1. Create dev database: `bundle exec rake db:setup`
1. Go to the file `config/settings/development.yml` in your local vets-api. Switch the commented out lines pertaining to the cache_dir: uncomment out line 14 (what you use for running the app via Rails), and comment out line 15 (what you use for running the app via Docker).
1. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed
