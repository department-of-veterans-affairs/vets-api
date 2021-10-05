# frozen_string_literal: true

require 'common/virus_scan'

class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          cached_path = get.download.path
          result = Common::VirusScan.scan(cached_path)
          Rails.logger.info('ValidateVirusFree Common::VirusScan result', result)
          result.safe? || add_error_msg(message || result.body)
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
