# frozen_string_literal: true

require 'yaml'
require 'rake'
require 'parallel_tests'
require 'fileutils'

module VetsApi
  module Setups
    class Docker
      # check for case where already done
      def run
        puts "\nDocker Setup... "
        configuring_clamav_antivirus
        docker_build
        setup_db
        setup_parallel_spec
        puts "\nDocker Setup Complete!"
      end

      private

      def configuring_clamav_antivirus
        print 'Configuring ClamAV...'
        File.open("config/initializers/clamav.rb", "w") do |file|
          file.puts <<~CLAMD
            if Rails.env.development?
              ENV['CLAMD_TCP_HOST'] = 'clamav'
              ENV['CLAMD_TCP_PORT'] = '3310'
            end
          CLAMD
        end
        puts 'Done'
      end

      # Should validate this before saying done
      def docker_build
        puts 'Building Docker Image(s) for This may take a while...'
        system('docker-compose build')
        # system('docker-compose -f docker-compose.test.yml build')
        puts 'Building Docker Image(s)...Done'
      end

      # Should validate this before saying done
      def setup_db
        puts 'Setting up database...'
        system('docker-compose run --rm --service-ports web bash -c "bundle exec rails db:setup"')
        puts 'Setting up database...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        system('docker-compose run --rm --service-ports web bash -c "RAILS_ENV=test bundle exec rake parallel:setup"')
        puts 'Setting up parallel_test...Done'
      end
    end
  end
end
