# frozen_string_literal: true

require 'yaml'
require 'rake'
require 'fileutils'

module VetsApi
  module Setups
    module Rails
      def install_bundler
        print "Installing bundler gem v#{bundler_version}..."
        ShellCommand.run_quiet("gem install bundler -v #{bundler_version}")
        puts 'Done'
      end

      def install_gems
        print 'Installing all gems...'
        `bundle install`
        puts 'Done'
      end

      def configuring_clamav_antivirus
        print 'Configuring ClamAV in local settings...'
        settings_path = 'config/settings.local.yml'
        settings_file = File.read(settings_path)
        settings = YAML.safe_load(settings_file, permitted_classes: [Symbol])
        settings.delete('clamav')

        settings['clamav'] = {
          'mock' => true,
          'host' => '0.0.0.0',
          'port' => '33100'
        }

        updated_yaml = settings.to_yaml
        updated_content = settings_file.gsub(/clamav:.*?(?=\n\w|\Z)/m,
                                             updated_yaml.match(/clamav:.*?(?=\n\w|\Z)/m).to_s)

        File.write(settings_path, updated_content)
        puts 'Done'
      end

      def install_pdftk
        if pdftk_installed?
          puts 'Skipping pdftk install (daemon already installed)'
        else
          puts 'Installing pdftk...'
          ShellCommand.run('brew install pdftk-java')
          puts 'Installing pdftk...Done'
        end
      end

      def setup_db
        puts 'Setting up database...'
        ShellCommand.run_quiet('bundle exec rails db:prepare')
        puts 'Setting up database...Done'
      end

      def setup_features
        puts 'Setting up Flipper features...'
        ShellCommand.run_quiet('bundle exec rake features:setup')
        puts 'Setting up Flipper features...Done'
      end

      def setup_parallel_spec
        puts 'Setting up parallel_test...'
        ShellCommand.run_quiet('RAILS_ENV=test bundle exec rake parallel:setup')
        puts 'Setting up parallel_test...Done'
      end

      private

      def bundler_version
        lockfile_path = "#{Dir.pwd}/Gemfile.lock"
        lines = File.readlines(lockfile_path).reverse

        bundler_line = lines.each_with_index do |line, index|
          break index if line.strip == 'BUNDLED WITH'
        end
        lines[bundler_line - 1].strip
      end

      def pdftk_installed?
        ShellCommand.run_quiet('pdftk --help')
      end

      def desired_clamav_config
        {
          'mock' => true,
          'host' => '0.0.0.0',
          'port' => '33100'
        }
      end
    end
  end
end
