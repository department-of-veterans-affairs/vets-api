# frozen_string_literal: true
class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          if ClamScan.configuration.client_location.blank?
            Shrine.logger.error('NO VIRUS SCANNING ENABLED')
            return
          end
          cached_path = get.download.path
          result = ClamScan::Client.scan(location: cached_path)
          # TODO: Log a the full result to sentry
          result.safe? || add_error(message) && false
        end

        private

        def add_error(*args)
          errors << error_message(*args)
        end

        def error_message(message)
          message || 'virus or malware detected'
        end
      end
    end

    register_plugin(:validate_virus_free, ValidateVirusFree)
  end
end
