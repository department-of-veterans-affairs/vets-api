# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative '../setups/native'
require_relative '../setups/docker'
require_relative '../setups/hybrid'

module VetsApi
  module Commands
    class Setup
      class << self
        # TODO: run check to make sure in the correct directory /vets-api
        def run(args)
          puts 'Base Setup... '
          check_vets_api_directory
          setup_localhost_authentication_for_id_me
          create_local_settings
          clone_mockdata
          set_local_betamocks_cache_dir
          disable_signed_authentication_requests
          prompt_setup_sidekiq_enterprise
          store_developer_environment_preference(args.first)
          setup_developer_environment
        end

        private

        def check_vets_api_directory
          raise ScriptError, 'Error: only run this command in the app root directory' unless Dir.pwd.end_with?('vets-api')
        end

        def setup_localhost_authentication_for_id_me
          if File.exist?('config/certs/vetsgov-localhost.key')
            puts 'Skipping localhost authentication to ID.me (files already exist)'
          else
            print 'Setting up key & cert for localhost authentication to ID.me... '
            FileUtils.mkdir('config/certs')
            FileUtils.touch('config/certs/vetsgov-localhost.crt')
            FileUtils.touch('config/certs/vetsgov-localhost.key')
            puts 'Done'
          end
        end

        def create_local_settings
          if File.exist?('config/settings.local.yml')
            puts 'Skipping local settings (files already exist)'
          else
            print 'Copying default settings to local settings... '
            FileUtils.cp('config/settings.local.yml.example', 'config/settings.local.yml')
            puts 'Done'
          end
        end

        def clone_mockdata
          if File.exist?('../vets-api-mockdata/README.md')
            puts 'Skipping vets-api-mockdata clone (already installed)'
          else
            puts 'Cloning vets-api-mockdata to sibiling directory'
            repo_url = 'git@github.com:department-of-veterans-affairs/vets-api-mockdata.git'
            destination = '../'
            system("git clone #{repo_url} #{destination}mockdata")
          end
        end

        def set_local_betamocks_cache_dir
          existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])
          cache_settings = { 'betamocks' => { 'cache_dir' => '../vets-api-mockdata' } }
          if existing_settings.keys.include?('betamocks')
            puts 'Skipping betamocks cache_dir setting (setting already exists)'
          else
            print 'Editing config/settings.local.yml to set cache_dir for betamocks ...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts cache_settings.to_yaml.tr('---', '')
            end
            puts 'Done'
          end
        end

        def disable_signed_authentication_requests
          existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])
          saml_settings = { 'saml' => { 'authn_requests_signed' => false } }
          if existing_settings.keys.include?('saml')
            puts 'Skipping disable signed authentication request (setting already exists)'
          else
            print 'Editing config/settings.local.yml to disable signed authentication requests...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts saml_settings.to_yaml.tr('---', '')
            end
            puts 'Done'
          end
        end

        # TODO: figure out how to do this with docker
        def prompt_setup_sidekiq_enterprise
          existing = system('echo $BUNDLE_ENTERPRISE__CONTRIBSYS__COM')
          print 'Enter Sidekiq Enterprise License or press enter/return to skip: '
          response = $stdin.gets.chomp
          key_regex = /\A[0-9a-fA-F]{8}:[0-9a-fA-F]{8}\z/

          if existing && response.empty?
            puts 'Skipping Sidekiq Enterprise License (value already set)'
          elsif response && key_regex.match?(response)
            print 'Setting Sidekiq Enterprise License... '
            `bundle config enterprise.contribsys.com #{response}`
            if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/i
              `set BUNDLE_ENTERPRISE__CONTRIBSYS__COM=#{response}"`
            else
              system("BUNDLE_ENTERPRISE__CONTRIBSYS__COM=#{response}")
            end
            puts 'Done'
          else
            puts
            puts "\e[1;4m**Please do not commit a Gemfile.lock that does not include sidekiq-pro and sidekiq-ent**\e[0m"
            puts
          end
        end

        def store_developer_environment_preference(input_environment)
          file_path = '.developer-environment'
          if input_environment
            File.write(file_path, input_environment.tr('--', ''))
          end
        end

        def setup_developer_environment
          case File.read('.developer-environment')
          when 'native'
            setup_native
          when 'docker'
            setup_docker
          when 'hybrid'
            setup_hybrid
          else
            puts "Invalid option for .developer-environment"
          end
        end

        def setup_native
          if RUBY_DESCRIPTION.include?('ruby 3.2.2')
            VetsApi::Setups::Native.new.run
          else
            puts "\nBefore continuing Ruby v3.2.2 must be installed"
            puts 'We suggest using a Ruby version manager such as rbenv, asdf, rvm, or chruby to install and maintain your version of Ruby.'
            puts 'More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md'
          end
        end

        def setup_docker
          if `docker -v`
            VetsApi::Setups::Docker.new.run
          else
            puts "\nBefore continuing Docker Desktop (Engine + Compose) must be installed"
            puts 'More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/docker.md'
          end
        end

        def setup_hybrid
          if RUBY_DESCRIPTION.include?('ruby 3.2.2') && `docker -v`
            VetsApi::Setups::Hybrid.new.run
          else
            puts "\nBefore continuing Ruby v3.2.2 AND Docker Desktop (Engine + Compose) must be installed"
            puts 'More information about Ruby managers: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md'
            puts 'More information about Docker Desktop (Engine + Compose): https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md'
          end
        end
      end
    end
  end
end
