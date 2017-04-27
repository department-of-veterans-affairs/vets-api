# frozen_string_literal: true
module DocumentUploads
  class PdfConversionJob
    include Sidekiq::Worker
    sidekiq_options retry: 5

    def perform(file_path)
      MiniMagick::Tool::Convert.new do |convert|
        convert << file_path
        convert << "#{file_path}.pdf"
      end
    rescue StandardError => e
      Rails.logger.error "Failed to convert image to pdf: #{e.message}"
      raise
    end
  end
end
