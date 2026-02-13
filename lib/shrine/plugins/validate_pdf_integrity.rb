# frozen_string_literal: true

class Shrine
  module Plugins
    module ValidatePdfIntegrity
      module AttacherMethods
        def validate_pdf_integrity
          return unless get.mime_type == Mime[:pdf].to_s

          file = get.download
          reader = PDF::Reader.new(file)

          errors << I18n.t('errors.messages.uploads.pdf.invalid') if reader.page_count < 1
        rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
          Rails.logger.warn("validate_pdf_integrity: #{e.message}")
          errors << I18n.t('errors.messages.uploads.malformed_pdf')
        end
      end
    end

    register_plugin(:validate_pdf_integrity, ValidatePdfIntegrity)
  end
end
