# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module VetsApi
  module Setups
    class Hybrid
      # check for case where already done
      def run
        puts "\nHybrid Setup... "
        install_bundler
        install_gems
        setup_db
        setup_parallel_spec
        configuring_clamav_antivirus
        dockerized_dependencies_settings
        install_pdftk
        puts "\nHybrid Setup Complete!"
      end

      private

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

      def install_gems
        print 'Installing all gems...'
        `bundle install`
        puts 'Done'
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

      def dockerized_dependencies_settings
        existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])

        db_settings = { 'database_url' => 'postgis://postgres:password@localhost:54320/vets_api_development?pool=4' }
        test_db_settings = { 'test_database_url' => 'postgis://postgres:password@localhost:54320/vets_api_test?pool=4' }

        redis_settings = {
          'redis' => {
            'host' => 'localhost',
            'port' => '63790',
            'app_data' => {
              'url' => 'redis://localhost:63790'
            },
            'sidekiq' => {
              'url' => 'redis://localhost:63790'
            }
          }
        }

        set_database_settings(existing_settings, db_settings, test_db_settings)
        set_redis_settings(existing_settings, redis_settings)
      end

      def set_database_settings(existing_settings, db_settings, test_db_settings)
        if existing_settings.keys.include?('database_url')
          puts 'Skipping database_url (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set database_url...'
          File.open('config/settings.local.yml', 'a') do |file|
            file.puts db_settings.to_yaml.tr('---', '')
          end
          puts 'Done'
        end

        if existing_settings.keys.include?('test_database_url')
          puts 'Skipping test_database_url (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set test_database_url...'
          File.open('config/settings.local.yml', 'a') do |file|
            file.puts test_db_settings.to_yaml.tr('---', '')
          end
          puts 'Done'
        end
      end

      def set_redis_settings(existing_settings, redis_settings)
        if existing_settings.keys.include?('redis')
          puts 'Skipping redis settings (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set redis...'
          File.open('config/settings.local.yml', 'a') do |file|
            file.puts redis_settings.to_yaml.tr('---', '')
          end
          puts 'Done'
        end
      end

      def docker_build
        puts 'Building Docker Image(s) for This may take a while...'
        ShellCommand.run_quiet('docker-compose -f docker-compose-deps.yml build')
        puts 'Building Docker Image(s)...Done'
      end

      def setup_db
        puts 'Setting up database...'
        ShellCommand.run_quiet('bundle exec rails db:prepare')
        puts 'Setting up database...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        ShellCommand.run_quiet('RAILS_ENV=test bundle exec rake parallel:setup')
        puts 'Setting up parallel_test...Done'
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
