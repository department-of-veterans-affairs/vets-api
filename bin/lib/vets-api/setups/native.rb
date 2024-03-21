# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module VetsApi
  module Setups
    class Native
      def run
        puts "\nNative Setup... "
        remove_other_setup_settings
        install_bundler
        if RbConfig::CONFIG['host_os'] =~ /darwin/i
          install_postgres_and_postgis
          run_brewfile
          pex_install_postis
          configuring_clamav_antivirus
          install_pdftk
        else
          "WARNING: bin/setup doesn't support Linux or Windows yet"
        end
        install_gems
        setup_db
        setup_parallel_spec
        puts "\nNative Setup Complete!"
      end

      private

      def remove_other_setup_settings
        print 'Removing other setup settings...'
        settings_path = 'config/settings.local.yml'
        settings_file = File.read(settings_path)
        settings = YAML.safe_load(settings_file, permitted_classes: [Symbol])
        hybrid_keys = %w[database_url test_database_url redis]

        hybrid_keys.each do |key|
          settings.delete(key) if settings.key?(key)
        end

        File.write(settings_path, YAML.dump(settings).tr('---', ''))
        puts 'Done'
      end

      def install_bundler
        print "Installing bundler gem v#{bundler_version}..."
        ShellCommand.run_quiet("gem install bundler -v #{bundler_version}")
        puts 'Done'
      end

      def bundler_version
        lockfile_path = "#{Dir.pwd}/Gemfile.lock"
        lines = File.readlines(lockfile_path).reverse

        bundler_line = lines.each_with_index do |line, index|
          break index if line.strip == 'BUNDLED WITH'
        end
        lines[bundler_line - 1].strip
      end

      def install_postgres
        ShellCommand.run('brew install postgres@14')
      end

      def run_brewfile
        print 'Installing binary dependencies...'
        ShellCommand.run_quiet('brew bundle')
        puts 'Done'
      end

      def pex_install_postis
        return if ShellCommand.run("psql -U postgres -d vets-api -c 'SELECT PostGIS_Version();' | grep -q '(1 row)'")

        g_cppflags = '-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include'
        cflags = '-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include'

        unless ShellCommand.run("G_CPPFLAGS='#{g_cppflags}' CFLAGS='#{cflags}' pex install postgis")
          puts "\n***ERROR***\n"
          puts 'There was an issue installing the postgis extension on postgres'
          puts 'You will need to install postgres and the extenstions via the app'
          puts
          puts '1. Download the Postgres.app with PostgreSQL 14 https://postgresapp.com/'
          puts '2. Follow the install instructions'
          puts '3. `sudo mkdir -p /etc/paths.d && echo /Applications/Postgres.app/Contents/Versions/latest/bin | sudo tee /etc/paths.d/postgresapp`'
          puts '4. `ARCHFLAGS="-arch x86_64" gem install pg -v 1.5.5`'
          puts '5. run postgres (e.g. open postgres.app, create a new server, and click "initialize")'
          puts '6. Now you can rerun the bin/setup command to finish the setup'
        end
      end

      def install_gems
        print 'Installing all gems...'
        `bundle install`
        puts 'Done'
      end

      # TODO: create a syscall to prevent logs (except errors) from logging
      def setup_db
        puts 'Setting up database...'
        ShellCommand.run_quiet('bundle exec rails db:setup')
        puts 'Setting up database...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        ShellCommand.run_quiet('RAILS_ENV=test bundle exec rake parallel:setup')
        puts 'Setting up parallel_test...Done'
      end

      def configuring_clamav_antivirus
        print 'Configuring ClamAV...'
        File.open('config/initializers/clamav.rb', 'w') do |file|
          file.puts <<~CLAMD
            # frozen_string_literal: true

            if Rails.env.development?
              ENV['CLAMD_TCP_HOST'] = '0.0.0.0'
              ENV['CLAMD_TCP_PORT'] = '33100'
            end
          CLAMD
        end
        puts 'Done'
      end

      def install_pdftk
        if pdftk_installed?
          puts 'Skipping pdftk install (binary already installed)'
        else
          puts 'Installing pdftk...'
          pdftk_url = 'https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg'
          ShellCommand.run_quiet("curl -o ~/Downloads/pdftk_download.pkg #{pdftk_url}")
          ShellCommand.run_quiet('sudo installer -pkg ~/Downloads/pdftk_download.pkg -target /')
          puts 'Installing pdftk...Done'
        end
      end

      def pdftk_installed?
        ShellCommand.run_quiet('pdftk --help')
      end
    end
  end
end
