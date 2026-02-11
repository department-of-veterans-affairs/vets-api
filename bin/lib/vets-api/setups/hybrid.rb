# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module VetsApi
  module Setups
    class Hybrid
      include Rails

      def run
        puts "\nHybrid Setup... "
        install_bundler
        install_gems
        setup_db
        setup_features
        setup_parallel_spec
        configuring_clamav_antivirus
        dockerized_dependencies_settings
        install_pdftk
        puts "\nHybrid Setup Complete!"
      end

      private

      def dockerized_dependencies_settings
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

        set_database_settings(db_settings, test_db_settings)
        set_redis_settings(redis_settings)
      end

      def set_database_settings(db_settings, test_db_settings)
        if existing_settings.keys.include?('database_url')
          puts 'Skipping database_url (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set database_url...'
          save_settings(db_settings)
          puts 'Done'
        end

        if existing_settings.keys.include?('test_database_url')
          puts 'Skipping test_database_url (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set test_database_url...'
          save_settings(test_db_settings)
          puts 'Done'
        end
      end

      def set_redis_settings(redis_settings)
        if existing_settings.keys.include?('redis')
          puts 'Skipping redis settings (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set redis...'
          save_settings(redis_settings)
          puts 'Done'
        end
      end

      def docker_build
        puts 'Building Docker Image(s) for This may take a while...'
        ShellCommand.run_quiet('docker compose -f docker-compose-deps.yml build')
        puts 'Building Docker Image(s)...Done'
      end

      def existing_settings
        YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])
      end

      def save_settings(settings)
        File.open('config/settings.local.yml', 'a') do |file|
          file.puts settings.to_yaml.sub(/^---\n/, '')
        end
      end
    end
  end
end
