# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'rails'

module VetsApi
  module Setups
    class Docker
      def run
        puts "\nDocker Setup (This will take a while)... "
        configuring_clamav_antivirus
        docker_build
        setup_db
        setup_parallel_spec
        puts "\nDocker Setup Complete!"
      end

      private

      def configuring_clamav_antivirus
        print 'Configuring ClamAV in local settings...'
        file_path = 'config/settings.local.yml'
        data = YAML.load_file(file_path)

        data['clamav'] = {
          'mock' => true,
          'host' => 'clamav',
          'port' => '3310'
        }

        File.write(file_path, data.to_yaml)

        puts 'Done'
      end

      # Should validate this before saying done
      def docker_build
        puts 'Building Docker Image(s) for This may take a while...'
        ShellCommand.run_quiet('docker compose build')
        puts 'Building Docker Image(s)...Done'
      end

      # Should validate this before saying done
      def setup_db
        puts 'Setting up database...'
        execute_docker_command('bundle exec rails db:prepare')
        puts 'Setting up database...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        execute_docker_command('RAILS_ENV=test bundle exec rails parallel:setup')
        puts 'Setting up parallel_test...Done'
      end

      def execute_docker_command(command)
        ShellCommand.run_quiet("docker compose run --rm --service-ports web bash -c \"#{command}\"")
      end
    end
  end
end
