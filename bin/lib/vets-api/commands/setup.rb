# frozen_string_literal: true

require_relative '../setups/base'
require_relative '../setups/native'
require_relative '../setups/docker'
require_relative '../setups/hybrid'
require './rakelib/support/shell_command'

module VetsApi
  module Commands
    class Setup
      class << self
        # TODO: run check to make sure in the correct directory /vets-api
        def run(args)
          setup_base
          store_developer_environment_preference(args.first)
          setup_developer_environment
        end

        private

        def setup_base
          VetsApi::Setups::Base.new.run
        end

        def store_developer_environment_preference(input_environment)
          file_path = '.developer-setup'
          File.write(file_path, input_environment.tr('--', '')) if input_environment
        end

        def setup_developer_environment
          case File.read('.developer-setup')
          when 'native'
            setup_native
          when 'docker'
            setup_docker
          when 'hybrid'
            setup_hybrid
          else
            puts 'Invalid option for .developer-setup'
          end
        end

        def setup_native
          if RUBY_DESCRIPTION.include?('ruby 3.2.2')
            VetsApi::Setups::Native.new.run
          else
            puts "\nBefore continuing Ruby v3.2.2 must be installed"
            puts 'We suggest using a Ruby version manager such as rbenv, asdf, rvm, or chruby \
                  to install and maintain your version of Ruby.'
            puts 'More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md'
          end
        end

        def setup_docker
          if docker_running?
            VetsApi::Setups::Docker.new.run
          else
            puts "\nBefore continuing Docker Desktop (Engine + Compose) must be installed"
            puts 'More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/docker.md'
          end
        end

        def setup_hybrid
          if RUBY_DESCRIPTION.include?('ruby 3.2.2') && docker_running?
            VetsApi::Setups::Hybrid.new.run
          else
            puts "\nBefore continuing Ruby v3.2.2 AND Docker Desktop (Engine + Compose) must be installed"
            puts 'More information about Ruby managers: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md'
            puts 'More information about Docker Desktop (Engine + Compose): https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md'
          end
        end

        def docker_running?
          ShellCommand.run_quiet('docker -v')
        end
      end
    end
  end
end
