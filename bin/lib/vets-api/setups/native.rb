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
          install_postgres
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
        ShellCommand.run('brew install postgresql@15')
      end

      def run_brewfile
        print 'Installing binary dependencies...(this might take a while)...'
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
          puts 'Follow the instructions on:'
          puts 'https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/native.md#osx'

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
        print 'Configuring ClamAV in local settings...'
        file_path = 'config/settings.local.yml'
        data = YAML.load_file(file_path)

        data['clamav'] = {
          'mock' => true,
          'host' => '0.0.0.0',
          'port' => '33100'
        }

        File.open(file_path, 'w') do |file|
          file.write(data.to_yaml)
        end

        puts 'Done'
      end

      def install_pdftk
        if pdftk_installed?
          puts 'Skipping pdftk install (daemon already installed)'
        else
          puts 'Installing pdftk...'
          ShellCommand.run('brew install pdftk-java')
          puts 'Installing pdftk...Done'
        end
      end

      def pdftk_installed?
        ShellCommand.run_quiet('pdftk --help')
      end
    end
  end
end
