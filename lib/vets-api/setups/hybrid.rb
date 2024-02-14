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
        dockerized_dependencies
        puts "\nHybrid Setup Complete!"
        puts
        puts 'Follow the Platform Specific Notes instructions, but skip any steps related to installing Postgres, Postgis, or Redis.'
        puts 'You will need to install the other dependencies such as pdftk and clamav.'
        puts 'https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/native.md#platform-specific-notes'
      end

      private

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

      def configuring_clamav_antivirus
        print 'Configuring ClamAV...'
        File.open("config/initializers/clamav.rb", "w") do |file|
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

      def dockerized_dependencies
        existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])

        database_settings = { 'database_url' => 'postgis://postgres:password@localhost:54320/vets_api_development?pool=4' }
        test_database_settings = { 'test_database_url' => 'postgis://postgres:password@localhost:54320/vets_api_test?pool=4' }

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

        if existing_settings.keys.include?('database_url')
          puts 'Skipping database_url (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set database_url...'
          File.open('config/settings.local.yml', 'a') do |file|
            file.puts database_settings.to_yaml.tr('---', '')
          end
          puts 'Done'
        end

        if existing_settings.keys.include?('test_database_url')
          puts 'Skipping test_database_url (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set test_database_url...'
          File.open('config/settings.local.yml', 'a') do |file|
            file.puts test_database_settings.to_yaml.tr('---', '')
          end
          puts 'Done'
        end

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
        system('docker-compose -f docker-compose-deps.yml build')
        puts 'Building Docker Image(s)...Done'
      end

      def setup_db
        puts 'Setting up database...'
        `bundle exec rails db:setup`
        puts 'Setting up database...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        system("RAILS_ENV=test bundle exec rake parallel:setup")
        puts 'Setting up parallel_test...Done'
      end

    end
  end
end
