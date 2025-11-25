# Developer Setup for users starting on a fresh Mac without any of the needed software installed.

Created to walk users through the entire process of setting up the Vets-API locally.

---

## Cloning the Vets-API Repo

Start by cloning the repository and navigating into the project directory.

```bash
git clone https://github.com/department-of-veterans-affairs/vets-api.git
cd vets-api
```

Create the required certs directory and files:

```bash
mkdir -p config/certs
touch config/certs/vetsgov-localhost.crt
touch config/certs/vetsgov-localhost.key
```

---

## Installing Homebrew

Install [Homebrew](https://brew.sh/) — the macOS package manager:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Update your shell profile:

```bash
echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

---

## Installing a Ruby Version Manager

We suggest using [`rbenv`](https://github.com/rbenv/rbenv) to install and maintain your version of Ruby.

```bash
brew install rbenv
rbenv init
```

> Follow the on-screen instructions to add `rbenv` to your shell configuration or restart your terminal.

Install the required Ruby version:

```bash
rbenv install 3.3.6
rbenv local 3.3.6
```

Verify Ruby is installed:

```bash
ruby -v
```

---

## Installing Bundler and Dependencies

Install [Bundler](https://bundler.io/) to manage Ruby gem dependencies:

```bash
gem install bundler
bundle install
```

---

### Bundler Troubleshooting

#### If `pg` (PostgreSQL gem) fails to install:

```bash
brew install libpq
brew link --force libpq
bundle config --local build.pg --with-pg-config=$(brew --prefix libpq)/bin/pg_config
bundle install
```

#### If `nokogiri` fails:

```bash
brew install xz
bundle install
```

#### If `mimemagic` fails:

```bash
brew install shared-mime-info
bundle install
```

---

## Installing Rails

```bash
sudo gem install rails
```

Verify Rails:

```bash
rails -v
```

---

## Installing PostgreSQL

We recommend using the [Postgres.app](https://postgresapp.com/):

1. Download **Postgres.app with PostgreSQL 15**
2. Open the app and click **"Initialize"**
3. Confirm that **PostgreSQL 15** is running

---

## Installing Redis

```bash
brew install redis
brew services start redis
```

---

## Installing Other Binary Dependencies

Use `brew bundle` to install required packages defined in the Brewfile:

```bash
brew bundle
```

> ⏳ This may take ~15 minutes depending on your system.

---

## Installing PDFTK

```bash
brew install pdftk-java
```

---

## Setting Up the Database

Make sure you're in the `vets-api` directory:

```bash
rails db:create db:schema:load db:migrate db:seed
```

---

## Cloning `vets-api-mockdata`

Clone the mock data repo into a **sibling directory** of `vets-api`:

```bash
cd ..
git clone https://github.com/department-of-veterans-affairs/vets-api-mockdata.git
```

### If authentication fails:

You may need to generate a GitHub Personal Access Token:

1. Go to: [https://github.com/settings/tokens](https://github.com/settings/tokens)
2. Choose **"Tokens (classic)"**
3. Click **"Generate new token"**
4. Select the following scopes:
   - `repo`
5. Set an expiration (e.g., 30 days)
6. Use this token as the password when cloning the repo

---

## Configuring Cache Directory

### Update `config/settings/development.yml`:

```yaml
cache_dir: ../vets-api-mockdata
```

### Create `config/settings.local.yml`:

```yaml
# config/settings.local.yml
betamocks:
  cache_dir: ../vets-api-mockdata
```

---

## Final Setup

Run the built-in setup script to finish installation:

```bash
bin/setup
```

This script will:

- Prepare your database
- Install missing dependencies
- Set up your local environment

---

## You're Done!

At this point, your local Vets-API environment should be fully set up and ready to run. 🎉

> Need help? Refer to the [original repo documentation](https://github.com/department-of-veterans-affairs/vets-api#readme) or reach out to your team.
