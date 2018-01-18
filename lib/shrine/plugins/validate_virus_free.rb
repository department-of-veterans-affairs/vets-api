# frozen_string_literal: true

class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          cached_path = get.download.path
          # `clamd` runs within service group, needs group read
          File.chmod(0o640, cached_path)
          result = ClamScan::Client.scan(location: cached_path)
          # TODO: Log a the full result to sentry
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
