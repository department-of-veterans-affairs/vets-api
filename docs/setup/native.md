
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
2. Install Bundler to manage dependencies
   - `gem install bundler`
3. Install Postgres and enable on startup
   - `brew install postgres`
   - `brew services start postgres`
4. Install PostGIS
   - `brew install postgis`
5. Install Redis
   - `brew install redis`
   - Follow post-install instructions to enable Redis on startup. Otherwise,
    launch it manually with `brew services start redis`.
6. Install ImageMagick
   - `brew install imagemagick`
7. Install Poppler
   -  `brew install poppler`
8. Install ClamAV

  - `brew install clamav`
  - Take note of the the post-install instructions "To finish installation & run clamav you will need to edit the example conf files at `${conf_files_dir}`", which will vary depending on your homebrew installation

    - `cd ${conf_files_dir}` 
    - `touch clamd.sock`
    - `echo "LocalSocket ${conf_files_dir}" > clamd.conf` 
    - `echo "DatabaseMirror database.clamav.net" > freshclam.conf`
    - `freshclam -v`

9. Install [pdftk](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg)
10. Install gem dependencies: `cd vets-api; bundle install`

   - More information about installing *with* Sidekiq Enterprise as well as our credentials are on the internal system here: https://github.com/department-of-veterans-affairs/vets-api#authentication-required-for-enterprisecontribsyscom

11. Install overcommit `overcommit --install --sign`
12. Setup localhost certificates / keys:
   - Create certs directory within config:  `mkdir ./config/certs`
   - Copy the [certificate][certificate] to `./config/certs/vetsgov-localhost.crt`
   - Copy the [key][key] to `./config/certs/vetsgov-localhost.key`
   - *NOTE*: If you don't have access to these keys, running the following
     commands will provide basic functionality, such as for running unit tests:
   - `touch ./config/certs/vetsgov-localhost.crt`
   - `touch ./config/certs/vetsgov-localhost.key`
13. Create dev database: `bundle exec rake db:setup`
14. Go to the file `config/settings/development.yml` in your local vets-api. Switch the commented out lines pertaining to the cache_dir: uncomment out line 14 (what you use for running the app via Rails), and comment out line 15 (what you use for running the app via Docker).
15. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed, preferably in a parallel directory to `vets-api`.
16. Make sure you have the [vets-api-mockdata](https://github.com/department-of-veterans-affairs/vets-api-mockdata) repo locally installed
17. Create a `config/settings.local.yml` file for your local configuration overrides. Add this key pointing to your `vets-api-mockdata` directory. 
```
betamocks:
  cache_dir: ../vets-api-mockdata
```

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
   - Copy [these certificates](https://github.com/department-of-veterans-affairs/vets.gov-team/tree/master/Products/Identity/Files_From_IDme/development-certificates) into the certs dir.
       - *NOTE*: If you don't have access to these keys, running the following
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
