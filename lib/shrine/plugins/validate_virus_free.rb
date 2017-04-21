# frozen_string_literal: true
class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          cached_path = "#{Rails.root}/#{get.to_io.path}"
          ClamScan::Client.scan(location: cached_path).safe? or add_error(message) && false
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
