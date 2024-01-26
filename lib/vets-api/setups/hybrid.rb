require 'yaml'
require 'pry'
require 'fileutils'

module VetsApi
  module Setups
    class Hybrid

      # Keep initialize for future command options
      def initialize
        super
      end

      # check for case where already done
      def run
        puts "\nHybrid Setup... "
        install_bundler
        install_gems
        setup_db
        clone_mockdata
        set_local_betamocks_cache_dir
        configuring_clamav_antivirus
        dockerized_dependencies
        puts "\nHybrid Setup Complete!"
        puts
        puts "Follow the Platform Specific Notes instructions, but skip any steps related to installing Postgres, Postgis, or Redis."
        puts "You will need to install the other dependencies such as pdftk and clamav."
        puts "https://github.com/department-of-veterans-affairs/vets-api/blob/master/docs/setup/native.md#platform-specific-notes"
      end

      private

        def install_bundler
          if `gem install bundler -v #{bundler_version}`
            puts "Bundler installed (#{bundler_version})"
          end
        end

        def bundler_version
          lockfile_path = Bundler.default_lockfile.to_s
          lines = File.readlines(lockfile_path).reverse

          bundler_line = lines.each_with_index do |line, index|

            break index if line.strip == "BUNDLED WITH"

          end
          lines[bundler_line - 1].strip
        end

        def install_gems
          if `bundle install`
            puts "Gems installed"
          end
        end

        # TODO: create a syscall to prevent logs (except errors) from logging
        def setup_db
          if `bundle exec rails db:setup`
            puts "Database created, schema loaded, seeds added"
          end
        end

        def mockdata_installed
          File.exist?("../vets-api-mockdata/README.md")
        end

        def clone_mockdata
          if mockdata_installed
            puts "Skipping vets-api-mockdata clone (already installed)"
          else
            puts "Cloning vets-api-mockdata to sibiling directory"
            repo_url = "git@github.com:department-of-veterans-affairs/vets-api-mockdata.git"
            destination = "../"
            system("git clone #{repo_url} #{destination}mockdata")
          end
        end

        def set_local_betamocks_cache_dir
          existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])
          cache_settings = { "betamocks" => {"cache_dir" => "../vets-api-mockdata"} }
          if existing_settings.keys.include?("betamocks")
            puts "Skipping betamocks cache_dir setting (setting already exists)"
          else
            print '  Editing config/settings.local.yml to set cache_dir for betamocks ...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts cache_settings.to_yaml.tr("---", "")
            end
            puts 'Done'
          end
        end

        def configuring_clamav_antivirus
          existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])
          cache_settings = { "binaries" => {"clamdscan" => "./bin/fake_clamdscan"} }
          if existing_settings.keys.include?("binaries")
            puts "Skipping ClamAV setting (setting already exists)"
          else
            print '  Editing config/settings.local.yml to set ClamAV path ...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts cache_settings.to_yaml.tr("---", "")
            end
            puts 'Done'
          end
        end

        def dockerized_dependencies
          existing_settings = YAML.safe_load(File.read('config/settings.local.yml'), permitted_classes: [Symbol])

          database_settings = {"database_url" => "postgis://postgres:password@localhost:54320/vets_api_development?pool=4"}
          test_database_settings = {"test_database_url" => "postgis://postgres:password@localhost:54320/vets_api_test?pool=4"}

          redis_settings = {
            "redis" => {
              "host" => "localhost",
              "port" => 63790,
              "app_data" => {
                "url" => "redis://localhost:63790"
              },
              "sidekiq" => {
                "url" => "redis://localhost:63790"
              }
            }
          }

          if existing_settings.keys.include?("database_url")
            puts "Skipping database_url (setting already exists)"
          else
            print 'Editing config/settings.local.yml to set database_url...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts database_settings.to_yaml.tr("---", "")
            end
            puts 'Done'
          end

          if existing_settings.keys.include?("test_database_url")
            puts "Skipping test_database_url (setting already exists)"
          else
            print 'Editing config/settings.local.yml to set test_database_url...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts test_database_settings.to_yaml.tr("---", "")
            end
            puts 'Done'
          end

          if existing_settings.keys.include?("redis")
            puts "Skipping redis settings (setting already exists)"
          else
            print 'Editing config/settings.local.yml to set redis...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts redis_settings.to_yaml.tr("---", "")
            end
            puts 'Done'
          end

        end
    end
  end
end
