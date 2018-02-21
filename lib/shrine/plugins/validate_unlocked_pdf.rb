# frozen_string_literal: true

class Shrine
  module Plugins
    module ValidateUnlockedPdf
      module AttacherMethods
        def validate_unlocked_pdf
          return unless get.mime_type == Mime[:pdf].to_s
          cached_path = get.download
          xref = PDF::Reader::XRef.new cached_path
          errors << I18n.t('uploads.pdf.locked') if xref.trailer[:Encrypt].present?
        rescue PDF::Reader::MalformedPDFError
          errors << I18n.t('uploads.pdf.invalid')
        end
      end
    end

    register_plugin(:validate_unlocked_pdf, ValidateUnlockedPdf)
  end
end
