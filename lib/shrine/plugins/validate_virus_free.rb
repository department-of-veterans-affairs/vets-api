# frozen_string_literal: true

require 'common/virus_scan'
require 'ddtrace'

class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          Datadog::Tracing.trace('Scan Upload for Viruses') do
            file_to_scan = get.download
            temp_file_path = Common::FileHelpers.generate_clamav_temp_file(file_to_scan)
            result = Common::VirusScan.scan(temp_file_path)
            File.delete(temp_file_path)
            result || add_error_msg(message || "Virus Found + #{temp_file_path}")
          end
        end

        private

        def add_error_msg(message)
          if Rails.env.development? && message.match(/nodename nor servname provided/)
            Shrine.logger.error('VIRUS SCANNING IS OFF. PLEASE START CLAMD')
            true
          else
            errors << (message || 'virus or malware detected')
            false
          end
        end
      end
    end

    register_plugin(:validate_virus_free, ValidateVirusFree)
  end
end
