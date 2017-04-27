# frozen_string_literal: true
module DocumentUploads
  class PdfDatestampJob
    include Sidekiq::Worker
    sidekiq_options retry: 5

    def perform(file_path, string, x, y)
      stamp_path = Rails.root.join('tmp/pdfs/', "#{SecureRandom.uuid}.pdf")
      generate_stamp(stamp_path, string, x, y)
      stamp(file_path, stamp_path)
    end

    private

    def generate_stamp(stamp_path, string, x, y)
      Prawn::Document.generate stamp_path do |pdf|
        pdf.draw_text Time.now.utc.strftime("#{string} %FT%T%:z"), at: [x, y], size: 10
      end
    rescue StandardError => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      raise
    end

    def stamp(file_path, stamp_path)
      stamp = CombinePDF.load(stamp_path).pages[0]
      original = CombinePDF.load(file_path)
      original.pages.each { |page| page << stamp }
      original.save file_path
    rescue => e
      Rails.logger.error "Failed to datestamp PDF file: #{e.message}"
      raise
    ensure
      File.delete(stamp_path)
    end
  end
end
