# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'rails'

module VetsApi
  module Setups
    class Native
      include Rails

      def run
        puts "\nNative Setup... "
        remove_other_setup_settings
        install_bundler
        if RbConfig::CONFIG['host_os'] =~ /darwin/i
          install_postgres
          run_brewfile
          validate_postgis_installed
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
        print 'Updating settings.local.yml...'
        settings_path = 'config/settings.local.yml'
        settings_file = File.read(settings_path)
        settings = YAML.safe_load(settings_file, permitted_classes: [Symbol])
        hybrid_keys = %w[database_url test_database_url redis]

        hybrid_keys.each do |key|
          settings.delete(key) if settings.key?(key)
        end

        lines = File.readlines(settings_path)
        updated_lines = lines.reject do |line|
          hybrid_keys.any? { |key| line.strip.start_with?("#{key}:") }
        end
        File.open(settings_path, 'w') do |file|
          file.puts updated_lines
        end

        puts 'Done'
      end

      def install_postgres
        if ShellCommand.run_quiet('pg_isready') && ShellCommand.run_quiet('pg_config')
          puts 'Skipping Postgres install (already running)'
        elsif ShellCommand.run_quiet('pg_config')
          puts 'ERROR:'
          puts "\nMake sure postgres is running before continuing"
          exit 1
        else
          ShellCommand.run('brew install postgresql@15')
        end
      end

      def run_brewfile
        print 'Installing binary dependencies...(this might take a while)...'
        ShellCommand.run_quiet('brew bundle')
        puts 'Done'
      end

      def validate_postgis_installed
        ShellCommand.run_quiet("psql -U postgres -d postgres -c 'CREATE EXTENSION IF NOT EXISTS postgis;'")
        return if ShellCommand.run("psql -U postgres -d postgres -c 'SELECT PostGIS_Version();' | grep -q '(1 row)'")

        g_cppflags = '-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include'
        cflags = '-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H -I/usr/local/include'

        unless ShellCommand.run("G_CPPFLAGS='#{g_cppflags}' CFLAGS='#{cflags}' pex install postgis")
          puts "\n***ERROR***\n"
          puts 'There was an issue installing the postgis extension on postgres'
          puts 'You will need to install postgres and the extenstions via the app'
          puts
          puts 'Follow the instructions on:'
          puts 'https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/native.md#osx'
          exit 1
        end
      end
    end
  end
end
