# frozen_string_literal: true
class Shrine
  module Plugins
    module ValidateUnlockedPdf
      module AttacherMethods
        def validate_unlocked_pdf
          cached_path = get.to_io
          xref = PDF::Reader::XRef.new cached_path
          add_error(I18n.t('uploads.pdf.locked')) if xref.trailer[:Encrypt].present?
        rescue PDF::Reader::MalformedPDFError
          add_error(I18n.t('uploads.pdf.invalid'))
        end

        private

        def add_error(msg)
          errors << msg
        end
      end
    end

    register_plugin(:validate_unlocked_pdf, ValidateUnlockedPdf)
  end
end
