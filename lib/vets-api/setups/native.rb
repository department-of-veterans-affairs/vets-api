# frozen_string_literal: true

require 'yaml'
require 'pry'
require 'fileutils'

module VetsApi
  module Setups
    class Native
      def run
        puts "\nNative Setup... "
        remove_other_setup_settings
        install_bundler
        if RbConfig::CONFIG['host_os'] =~ /darwin/i
          run_brewfile
          configuring_clamav_antivirus
          install_pdftk
        else
          "WARNING: bin/setup doesn't support Linux or Windows yet"
        end
        install_gems
        setup_db
        setup_parallel_spec
        if RbConfig::CONFIG['host_os'] =~ /darwin/i
          puts
          puts 'Follow the Platform Specific Notes instructions to install Postgres & PostGIS'
          puts 'https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/native.md#osx'
        end
        puts "\nNative Setup Complete!"
      end

      private

      def remove_other_setup_settings
        print 'Removing other setup settings...'
        settings_path = 'config/settings.local.yml'
        settings_file = File.read(settings_path)
        settings = YAML.safe_load(settings_file, permitted_classes: [Symbol])
        hybrid_keys = %w(database_url test_database_url redis)

        hybrid_keys.each do |key|
          settings.delete(key) if settings.has_key?(key)
        end

        File.write(settings_path, YAML.dump(settings).tr('---', ''))
        puts 'Done'
      end

      def install_bundler
        print "Installing bundler gem v#{bundler_version}..."
        `gem install bundler -v #{bundler_version}`
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

      def install_gems
        print 'Installing all gems...'
        `bundle install`
        puts 'Done'
      end

      # TODO: create a syscall to prevent logs (except errors) from logging
      def setup_db
        puts 'Setting up databse...'
        `bundle exec rails db:setup`
        puts 'Setting up databse...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        system('RAILS_ENV=test bundle exec rake parallel:setup')
        puts 'Setting up parallel_test...Done'
      end

      def configuring_clamav_antivirus
        print 'Enabling ClamAV...'
        clam_directory = `brew --prefix clamav`.chomp
        FileUtils.touch("#{clam_directory}/clamd.sock")
        File.open("#{clam_directory}/clamd.conf", 'w') do |file|
          file.puts "LocalSocket #{clam_directory}/clamd.sock"
        end
        File.open("#{clam_directory}/freshclam.conf", 'w') do |file|
          file.puts 'DatabaseMirror database.clamav.net'
        end
        `freshclam -v`
        File.open("config/initializers/clamav.rb", "w") do |file|
          file.puts "ENV['CLAMD_UNIX_SOCKET'] = '#{clam_directory}/clamd.sock'"
        end
        puts 'Done'
      end

      def run_brewfile
        print 'Installing binary dependencies...'
        `brew bundle`
        puts 'Done'
      end

      def install_pdftk
        if `pdftk --help`
          puts "Skipping pdftk install (binary already installed)"
        else
          puts 'Installing pdftk...'
          `curl -o ~/Downloads/pdftk_download.pkg https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg`
          `sudo installer -pkg ~/Downloads/pdftk_download.pkg -target /`
          puts 'Installing pdftk...Done'
        end
      end
    end
  end
end
