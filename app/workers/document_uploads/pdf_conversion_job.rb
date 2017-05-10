# frozen_string_literal: true
# TODO(AJD): convert to workflow task
module DocumentUploads
  class PdfConversionJob
    include Sidekiq::Worker
    sidekiq_options retry: 5

    def perform(file_path)
      file_type = MIME::Types.type_for(file_path.to_s).first.try(:media_type).to_sym

      case file_type
      when :image
        convert_image_to_pdf(file_path)
      when :application || :text
        convert_markup_to_pdf(file_path)
      else
        raise ArgumentError "Unsupported file type: #{file_type} in PdfConversionJob"
      end
    rescue StandardError => e
      Rails.logger.error "Failed to convert image to pdf: #{e.message}"
      raise
    end

    def convert_image_to_pdf(file_path)
      MiniMagick::Tool::Convert.new do |convert|
        convert << file_path
        convert << "#{file_path}.pdf"
      end
    end

    def convert_markup_to_pdf(file_path)
      unless system "unoconv -o #{file_path}.pdf -f pdf #{file_path}"
        raise ProcessingError, "Unoconv failed to convert #{file_path}"
      end
    end
  end
  class ProcessingError < StandardError
  end
end
