# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module VetsApi
  module Setups
    class Base
      # check for case where already done
      def run
        puts 'Base Setup...'
        check_vets_api_directory
        setup_localhost_authentication_for_id_me
        create_local_settings
        clone_mockdata
        set_local_betamocks_cache_dir
        disable_signed_authentication_requests
        prompt_setup_sidekiq_enterprise
        puts 'Base Setup...Done'
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
        cache_settings = { 'betamocks' => { 'cache_dir' => '../vets-api-mockdata' } }
        if existing_settings.keys.include?('betamocks')
          puts 'Skipping betamocks cache_dir setting (setting already exists)'
        else
          print 'Editing config/settings.local.yml to set cache_dir for betamocks ...'
          save_settings(cache_settings)
          puts 'Done'
        end
      end

      def disable_signed_authentication_requests
        saml_settings = { 'saml' => { 'authn_requests_signed' => false } }
        if existing_settings.keys.include?('saml')
          puts 'Skipping disable signed authentication request (setting already exists)'
        else
          print 'Editing config/settings.local.yml to disable signed authentication requests...'
          save_settings(saml_settings)
          puts 'Done'
        end
      end

      # TODO: figure out how to do this with docker
      def prompt_setup_sidekiq_enterprise
        unless `bundle config get enterprise.contribsys.com --parseable`.empty?
          puts 'Skipping Sidekiq Enterprise License (value already set)'
          return true
        end

        print 'Enter Sidekiq Enterprise License or press enter/return to skip: '
        response = $stdin.gets.chomp
        if response && /\A[0-9a-fA-F]{8}:[0-9a-fA-F]{8}\z/.match?(response)
          print 'Setting Sidekiq Enterprise License... '
          ShellCommand.run_quiet("bundle config enterprise.contribsys.com #{response}")
          if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/i
            ShellCommand.run_quiet("set BUNDLE_ENTERPRISE__CONTRIBSYS__COM=#{response}")
          else
            ShellCommand.run_quiet("BUNDLE_ENTERPRISE__CONTRIBSYS__COM=#{response}")
          end
          puts 'Done'
        else
          puts
          puts "\e[1;4m**Please do not commit a Gemfile.lock that does not include sidekiq-pro and sidekiq-ent**\e[0m"
          puts
        end
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
