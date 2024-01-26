require 'yaml'
require 'fileutils'

module VetsApi
  module Setups
    class Docker

      # Keep initialize for future command options
      def initialize
        super
      end

      # check for case where already done
      def run
        puts "\nDocker Setup... "
        clone_mockdata
        set_local_betamocks_cache_dir
        configuring_clamav_antivirus
        puts "\nDocker Setup Complete!"
      end

      private

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
            print 'Editing config/settings.local.yml to set cache_dir for betamocks ...'
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
            print 'Editing config/settings.local.yml to set ClamAV path ...'
            File.open('config/settings.local.yml', 'a') do |file|
              file.puts cache_settings.to_yaml.tr("---", "")
            end
            puts 'Done'
          end
        end
    end
  end
end
