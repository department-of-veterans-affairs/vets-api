# frozen_string_literal: true

require 'common/file_helpers'

class Shrine
  module Plugins
    module ValidateCorrectFormPdftotext
      module AttacherMethods
        WRONG_FORM = 'wrong_form'
        ALLOWED_MIME_TYPE_STRINGS = %i[pdf png jpeg].map { |type| Mime[type].to_s }

        def validate_correct_form_pdftotext(form_id: nil)
          return unless ALLOWED_MIME_TYPE_STRINGS.include?(get.mime_type) && form_id

          image_path = Rails.root.join("#{Common::FileHelpers.random_file_path}.jpg").to_s
          file = get.download
          pdf = MiniMagick::Image.open(file.path)
          MiniMagick.convert do |convert|
            convert << pdf.pages.first.path
            convert.background 'white'
            convert.flatten
            convert.density 150
            convert.quality 100
            convert << image_path
          end
          if get.mime_type == 'pdf'
            file_as_string = Pdftotext.text(file.path)
            record.warnings << WRONG_FORM unless file_as_string.include? form_id
          end
        end
      end
    end

    register_plugin(:validate_correct_form_pdftotext, ValidateCorrectFormPdftotext)
  end
end
