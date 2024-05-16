# frozen_string_literal: true

require 'yaml'
require 'rake'
require 'fileutils'

module VetsApi
  module Setups
    class Docker
      # check for case where already done
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
        ShellCommand.run_quiet('docker-compose build')
        # system('docker-compose -f docker-compose.test.yml build')
        puts 'Building Docker Image(s)...Done'
      end

      # Should validate this before saying done
      def setup_db
        puts 'Setting up database...'
        ShellCommand.run_quiet('docker-compose run --rm --service-ports web bash -c "bundle exec rails db:prepare"')
        puts 'Setting up database...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        parallel_setup_command = 'RAILS_ENV=test bundle exec rake parallel:setup'
        ShellCommand.run_quiet("docker-compose run --rm --service-ports web bash -c \"#{parallel_setup_command}\"")
        puts 'Setting up parallel_test...Done'
      end
    end
  end
end
