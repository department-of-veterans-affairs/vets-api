# frozen_string_literal: true

require 'common/file_helpers'

class Shrine
  module Plugins
    module ValidateCorrectForm
      module AttacherMethods
        WRONG_FORM = 'wrong_form'

        def validate_correct_form(form_id: nil)
          return unless get.mime_type == Mime[:pdf].to_s && form_id

          image_path = Rails.root.join("#{Common::FileHelpers.random_file_path}.jpg").to_s
          file = get.download
          pdf = MiniMagick::Image.open(file.path)
          MiniMagick::Tool::Convert.new do |convert|
            convert.background 'white'
            convert.flatten
            convert.density 150
            convert.quality 100
            convert << pdf.pages.first.path
            convert << image_path
          end
          file_as_string = RTesseract.new(image_path).to_s

          record.warnings << WRONG_FORM unless file_as_string.include? form_id
        end
      end
    end

    register_plugin(:validate_correct_form, ValidateCorrectForm)
  end
end
