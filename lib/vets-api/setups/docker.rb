# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module VetsApi
  module Setups
    class Docker
      # check for case where already done
      def run
        puts "\nDocker Setup... "
        configuring_clamav_antivirus
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
    end
  end
end
