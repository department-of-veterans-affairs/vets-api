# frozen_string_literal: true

require_relative '../setups/base'
require_relative '../setups/native'
require_relative '../setups/docker'
require_relative '../setups/hybrid'
require_relative 'command'

module VetsApi
  module Commands
    class Setup < Command
      def self.run(args)
        Setup.new(args).execute # Command#execute
      end

      def execute
        execute_base
        case setup_preference
        when 'native'
          execute_native
        when 'hybrid'
          execute_hybrid
        when 'docker'
          execute_docker
        else
          puts 'Invalid option for .developer-setup'
        end
      end

      private

      def execute_base
        VetsApi::Setups::Base.new.run
        base_setup = @inputs.include?('base')
        store_developer_setup_preference unless base_setup
        exit 0 if base_setup
      end

      def execute_native
        validate_ruby_version
        VetsApi::Setups::Native.new.run
      end

      def execute_docker
        validate_docker_running
        VetsApi::Setups::Docker.new.run
      end

      def execute_hybrid
        validate_ruby_version
        validate_docker_running
        VetsApi::Setups::Hybrid.new.run
      end

      def store_developer_setup_preference
        setup = @inputs.split.first
        file_path = '.developer-setup'
        File.write(file_path, setup) if setup
      end

      def validate_ruby_version
        unless RUBY_DESCRIPTION.include?(ruby_version)
          puts "\nBefore continuing Ruby #{ruby_version} must be installed"
          puts 'We suggest using a Ruby version manager such as rbenv, asdf, rvm, or chruby' \
               ' to install and maintain your version of Ruby.'
          puts 'More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/native.md#installing-a-ruby-version-manager'
          exit 1
        end
      end

      def validate_docker_running
        unless docker_running?
          puts "\nBefore continuing Docker Desktop (Engine + Compose) must be installed"
          puts 'More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/docker.md'
          exit 1
        end
      end

      def docker_running?
        ShellCommand.run_quiet('docker -v')
      end

      def ruby_version
        File.read('.ruby-version').chomp
      end
    end
  end
end
