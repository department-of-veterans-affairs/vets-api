# frozen_string_literal: true

class Shrine
  module Plugins
    module ValidateAscii
      module AttacherMethods
        def validate_ascii
          return unless get.original_filename.ends_with?('.txt')
          text = get.to_io.read.encode('ascii')
          tempfile = Tempfile.new(encoding: 'ascii')
          tempfile.write text
          tempfile.flush
          tempfile.rewind
          get.replace(tempfile)
        rescue Encoding::UndefinedConversionError
          add_error(I18n.t('uploads.text.not_ascii'))
          false
        end

        private

        def add_error(msg)
          errors << msg
        end
      end
    end
    register_plugin(:validate_ascii, ValidateAscii)
  end
end
