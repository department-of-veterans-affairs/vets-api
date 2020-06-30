# frozen_string_literal: true

require 'pdf_info'

class Shrine
  module Plugins
    module ValidateUnlockedPdf
      module AttacherMethods
        def validate_unlocked_pdf
          return unless get.mime_type == Mime[:pdf].to_s

          cached_path = get.download
          metadata = PdfInfo::Metadata.read(cached_path)
          errors << I18n.t('uploads.pdf.locked') if metadata.encrypted?
        rescue PdfInfo::MetadataReadError
          errors << I18n.t('uploads.pdf.invalid')
        end
      end
    end

    register_plugin(:validate_unlocked_pdf, ValidateUnlockedPdf)
  end
end
