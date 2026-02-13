# Vets API Windows/WSL Setup Instructions

## Install WSL for Windows

1. In apps, search Microsoft Store and open the app.
2. In the Microsoft Store, search for the key phrase `wsl`.
3. From the returned results, select a version of Ubuntu (I used Ubuntu 24.04.1 LTS) and click get to install it.
4. Once installed, an Ubuntu app will be created. Open the app and begin setup instructions.
   - If an error occurs that prevents you from opening WSL, double check that virtualization is enabled on your Windows PC: [Enable Virtualization on Windows - Microsoft Support](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/enable-hyper-v-on-windows-10)
5. After Ubuntu is successfully installed, return to the Microsoft Store and search for VS Code. Click get to install VS Code.
6. After completing the VS Code installation, open up the application and navigate to extensions in the left sidebar.
7. In extensions, search for `wsl`. Install the WSL extension for VS Code. This will allow you to be able to open VS Code from the WSL Ubuntu terminal.

## Setup GitHub (with SSH)

1. In terminal run the following commands to set your GitHub credentials:

   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "youremail@domain.com"
   ```

2. Set up SSH keys with:

   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

3. Enter a passphrase (optional)
4. Once the key is created, start the SSH agent with:

   ```bash
   eval "$(ssh-agent -s)"
   ```

5. Add the new key to the agent (enter passphrase from step 7 if created):

   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```

6. Copy the public key output from this command:

    ```bash
    cat ~/.ssh/id_ed25519.pub
    ```

7. Go to GitHub SSH settings, click create new SSH key, create a name for the key, paste the key contents and save the key.
8. Validate SSH is working by running:

    ```bash
    ssh -T git@github.com
    ```

    The output will be:

    ```bash
    Hi your-github-username! You've successfully authenticated, but GitHub does not provide shell access.
    ```

9. When cloning repos, run the SSH commands instead of HTTPS:

    ```bash
    git clone git@github.com:owner/repo.git
    ```

## Setup asdf or RVM (Ruby Version Manager) for Ruby version management

> When running the setup steps, rbenv did not support version 3.3.6, so you can use asdf or RVM. *Note*: use only one of these and not both.

### asdf setup

1. Install Ruby version manager

    ```bash
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1

    echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
    echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
    echo 'legacy_version_file = yes' >> ~/.asdfrc
    echo 'export EDITOR="code --wait"' >> ~/.bashrc

    exec $SHELL
    ```

2. Add plugins for Ruby

    ```bash
    asdf plugin add ruby
    ```

3. Download Ruby (verify correct version)

    ```bash
    asdf install ruby 3.3.6
    asdf global ruby 3.3.6
    ruby -v
    ```

### RVM setup

1. Install GPG keys to verify installation package:

   ```bash
   gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
   ```

2. Follow setup steps for Ubuntu: [rvm/ubuntu_rvm: Ubuntu package for RVM](https://github.com/rvm/ubuntu_rvm)
3. With RVM installed, run the following command to install Ruby 3.3.6 (enter password if prompted):

   ```bash
   rvm install ruby-3.3.6
   ```

4. Verify the ruby version with:

   ```bash
   ruby -v
   ```

## Install and Setup vets-api

1. Open a WSL terminal.
2. In terminal, clone the repository using the command:

   ```bash
   git clone git@github.com:department-of-veterans-affairs/vets-api.git
   ```

3. Create the required certs directory and files:

   ```bash
   cd vets-api
   mkdir -p config/certs
   touch config/certs/vetsgov-localhost.crt
   touch config/certs/vetsgov-localhost.key
   ```

4. Copy the example configuration file:

   ```bash
   cp config/settings.local.yml.example config/settings.local.yml
   ```

5. Edit `config/settings.local.yml` to disable signed authentication requests:

   ```bash
   nano config/settings.local.yml
   ```

   Update the SAML configuration:

   ```yaml
   saml:
     authn_requests_signed: false
   ```

6. Uncomment `authn_requests_signed: false` and save the file.

7. Install dependencies for Ubuntu 20.04: [vets-api/docs/setup/native.md](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/native.md)

### Ubuntu 24.04.1 Dependencies Setup

If using Ubuntu 24.04.1, use the following steps; otherwise skip to Bundler commands.

#### Setup postgres-14

1. Run the following commands:

   ```bash
   echo "deb http://apt.postgresql.org/pub/repos/apt/ noble-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
   wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
   sudo apt update
   sudo apt install postgresql-14
   ```

2. Validate Postgres version with:

   ```bash
   psql --version
   ```

3. Once postgres is installed, open postgres, create a superuser, and exit the instance using the following commands:

   ```bash
   sudo -i -u postgres
   createuser --superuser YOURNAME
   exit
   ```

#### Install PostGIS for PostgreSQL-14

```bash
sudo apt install -y postgresql-14-postgis-3
sudo -i -u postgres

createuser postgis_test
createdb postgis_db -O postgis_test
psql -d postgis_db
```

Inside the psql prompt:

```sql
CREATE EXTENSION postgis;
SELECT PostGIS_version();
\q
```

Exit postgres:

```bash
exit
```

#### Install Redis

```bash
sudo apt install -y redis-server
sudo sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
sudo systemctl restart redis.service
sudo systemctl status redis
```

#### Install ImageMagick

```bash
sudo apt install -y imagemagick
```

#### Install Poppler

```bash
sudo apt install -y poppler-utils
```

#### Install pdftk

```bash
sudo apt install -y pdftk
```

## Install and run Bundler

1. Install Bundler to manage Ruby dependencies:

   ```bash
   sudo gem install bundler
   ```

2. Install gem dependencies inside vets-api directory:

   ```bash
   bundle install
   ```

   > **NOTE:** Ignore any warning messages about Sidekiq for your local. When you complete the redis installation, when you run:

   ```bash
   foreman start
   ```

   and naviate to ```http://localhost:3000/sidekiq```, you should be able to see the sidekiq GUI. Just make sure to not commit changes to Gemfile.lock.

3. Discard any changes made to the `Gemfile.lock`:

### Bundler Troubleshooting

If `pg` (PostgreSQL gem) fails to install:

```bash
sudo apt install libpq-dev
bundle install
```

## Install Rails

1. Install rails with the following command:

   ```bash
   sudo gem install rails
   ```

2. Validate with:

   ```bash
   rails -v
   ```

### Rails Troubleshooting

If you have an issue that returns:

```bash
You might have to install separate package for the ruby development
environment, ruby-dev or ruby-devel for example.
```

You can resolve the issue by running:

```bash
sudo apt update
sudo apt install ruby-dev build-essential
```

Then rerun `sudo gem install rails` inside the vets-api directory.

## Setup Local Databases and Run Migrations

1. In the vets-api directory:

   ```bash
   bin/rails db:create
   bin/rails db:setup
   bin/rails db:migrate
   ```

### Setup Databases and Migrations Troubleshooting

If you receive an error running `rails db:setup` that contains:

```bash
Caused by:
PG::ConnectionBad: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: FATAL:  role "SOME_NAME_HERE" does not exist (PG::ConnectionBad)
```

Then you need to create a user with role: "SOME_NAME_HERE" with the following:

```bash
sudo -i -u postgres
createuser --superuser SOME_NAME_HERE
exit
```

## Set Up vets-api-mockdata

1. Follow setup steps for vets-api-mockdata: [vets-api/docs/setup/new_machine.md](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/new_machine.md)
   - If using SSH, run the following command instead of the HTTPS command:

     ```bash
     git clone git@github.com:department-of-veterans-affairs/vets-api-mockdata.git
     ```

### Setup vets-api-mockdata Troubleshooting

If you receive an error where the repo cannot be found, make sure you have access to team lighthouse-dash: [lighthouse-dash · Department of Veterans Affairs Team](https://github.com/orgs/department-of-veterans-affairs/teams/lighthouse-dash)

## Configure Cached Directory in vets-api

1. Follow the setup steps for updating the development and settings yml files for your local environment: [vets-api/docs/setup/new_machine.md](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/new_machine.md)

## Running the Application Natively

1. Your setup should be complete. To validate, run the application using:

   ```bash
   foreman start -m all=1,clamd=0,freshclam=0
   ```

2. Navigate to `localhost:3000/v0/status` to validate that all services are running.

## Tests Setup

1. Follow the setup steps for setting up test DBs and setting up tests to run in parallel: [vets-api/docs/setup/running_natively.md](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/running_natively.md)
2. Validate tests can run by running:

   ```bash
   RAILS_ENV=test NOCOVERAGE=true bundle exec parallel_rspec spec modules
   ```

## Congratulations! You are set up

## Helpful Resources

- [WSL Setup: Set up a WSL development environment | Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/setup/environment)
- [WSL Git: Get started using Git on WSL | Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-git)
- [RVM: Ruby Version Manager - Installing RVM](https://rvm.io/rvm/install)
- [rvm/ubuntu_rvm: Ubuntu package for RVM](https://github.com/rvm/ubuntu_rvm)
- [Team Lighthouse-Dash](https://github.com/orgs/department-of-veterans-affairs/teams/lighthouse-dash)
- [Running vets-api natively](https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/running_natively.md)
- [vets-api-mockdata repo](https://github.com/department-of-veterans-affairs/vets-api-mockdata)
