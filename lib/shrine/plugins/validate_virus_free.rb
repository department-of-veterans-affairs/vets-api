# frozen_string_literal: true

require 'common/virus_scan'
require 'ddtrace'

class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          Datadog::Tracing.trace('Scan Upload for Viruses') do
            cached_path = get.download.path
            result = Common::VirusScan.scan(cached_path)
            result.safe? || add_error_msg(message || result.body)
          end
        end

        private

        def add_error_msg(message)
          if Rails.env.development? && message.match(/nodename nor servname provided/)
            Rails.logger.error('VIRUS SCANNING IS OFF. PLEASE START CLAMD')
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
