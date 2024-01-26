require 'yaml'
require 'fileutils'

module VetsApi
  module Commands
    class Setup
      class << self

        # TODO: run check to make sure in the correct directory /vets-api
        def run(args)
          @change_environment = false
          if args.include?('--help') || args.include?('-h')
            puts <<~HELP
              Usage:
                bin/vets setup [options]

              Options:
                --help, -h        Display help message for 'setup'
                --change          Change developer environment
                --skip-basic      Skip to developer environment setup

              Examples:
                bin/vets setup --help                 Show help message
                bin/vets setup --change               Change developer environment
                bin/vets setup --skip-basic --change  Skip and change

            HELP
          else
            @change_environment = true if args.include?('--change')

            unless args.include?('--skip-basic')
              setup_localhost_authentication_for_id_me
              create_local_settings
              disable_signed_authentication_requests
              prompt_setup_sidekiq_enterprise
            end
            choose_developer_environment
          end
        end

        private

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
            FileUtils.cp('config/settings.local.yml.example','config/settings.local.yml')
            puts 'Done'
          end
        end

        def disable_signed_authentication_requests
          existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])
          saml_settings = { "saml" => {"authn_requests_signed" => false} }
          if existing_settings.keys.include?("saml")
            puts "Skipping disable signed authentication request (setting already exists)"
          else
            print 'Editing config/settings.local.yml to disable signed authentication requests...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts saml_settings.to_yaml.tr("---", "")
            end
            puts 'Done'
          end
        end

        def prompt_setup_sidekiq_enterprise
          existing = system('echo $BUNDLE_ENTERPRISE__CONTRIBSYS__COM')
          print "Enter Sidekiq Enterprise License or press enter/return to skip: "
          response = STDIN.gets.chomp
          key_regex = %r{\A[0-9a-fA-F]{8}:[0-9a-fA-F]{8}\z}

          if existing && response.empty?
            puts "Skipping Sidekiq Enterprise License (value already set)"
          elsif response && key_regex.match?(response)
            print "Setting Sidekiq Enterprise License... "
            `bundle config enterprise.contribsys.com #{response}`
            if RbConfig::CONGIF['host_os'] =~ /mswin|msys|mingw|cygwin/i
              `set BUNDLE_ENTERPRISE__CONTRIBSYS__COM=#{response}"`
              puts "Done"
            else
              system("BUNDLE_ENTERPRISE__CONTRIBSYS__COM=#{response}")
              puts "Done"
            end
          else
            puts
            puts "\e[1;4m**Please do not commit a Gemfile.lock that does not include sidekiq-pro and sidekiq-ent**\e[0m"
            puts
          end
        end

        def choose_developer_environment(repeat = false)
          file_path = '.developer-environment'
          environment = File.exist?(file_path) ? File.read(file_path) : ''
          environment = '' if @change_environment
          response =
            case environment
            when 'native'
              'n'
            when 'docker'
              'd'
            when 'hybrid'
              'h'
            else
              unless repeat
                puts <<~SETUP

                  Developers who work with vets-api daily tend to prefer the native setup because they don't have to deal with the
                  abstraction of docker-compose while those who would to spend less time on getting started prefer the docker setup.
                  Docker is also useful when it's necessary to have a setup as close to production as possible.
                  Finally, it's possible to use a hybrid setup where you run vets-api natively, but run the Postgres and Redis dependencies in docker.

                SETUP
              end
              print "Would like run vets-api natively, docker, or hybrid [n,d,h]: "
              STDIN.gets.chomp
            end


          if response == "n"
            if RUBY_DESCRIPTION.include?("ruby 3.2.2")
              VetsApi::Setups::Native.new.run
            else
              puts "\nBefore continuing Ruby v3.2.2 must be installed"
              puts "We suggest using a Ruby version manager such as rbenv, asdf, rvm, or chruby to install and maintain your version of Ruby."
              puts "More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md"
            end
            File.write(file_path,'native')
          elsif response == "d"
            if `docker -v`
              VetsApi::Setups::Docker.new.run
            else
              puts "\nBefore continuing Docker Desktop (Engine + Compose) must be installed"
              puts "More information: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/docker.md"
            end
            File.write(file_path,'docker')
          elsif response == "h"
            if RUBY_DESCRIPTION.include?("ruby 3.2.2") && `docker -v`
              VetsApi::Setups::Hybrid.new.run
            else
              puts "\nBefore continuing Ruby v3.2.2 AND Docker Desktop (Engine + Compose) must be installed"
              puts "More information about Ruby managers: https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md"
              puts "More information about Docker Desktop (Engine + Compose): https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/ruby_managers.md"
            end
            File.write(file_path,'hybrid')
          else
            puts "\nInvalid input #{response}"
            puts
            choose_developer_environment(true)
          end

        end
      end
    end
  end
end
