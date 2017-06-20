# frozen_string_literal: true
module Workflow::Task::Common
  class DatestampPdfTask < Workflow::Task::ShrineFile::Base
    def run(settings)
      in_path = @file.download.path
      FileUtils.mkdir_p Rails.root.join('tmp', 'pdfs')
      stamp_path = Rails.root.join('tmp', 'pdfs', "#{SecureRandom.uuid}.pdf")
      generate_stamp(stamp_path, settings[:text], settings[:x], settings[:y])
      out_path = stamp(in_path, stamp_path)
      update_file(io: File.open(out_path))
    ensure
      File.delete(out_path) if !out_path.nil? && File.exist?(out_path)
    end

    private

    def generate_stamp(stamp_path, text, x, y)
      text = Time.now.utc.strftime("#{text} %FT%T%:z")
      text += ('. ' + data[:append_to_stamp]) if data[:append_to_stamp]
      Prawn::Document.generate stamp_path do |pdf|
        pdf.draw_text text, at: [x, y], size: 10
      end
    rescue StandardError => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      raise
    end

    def stamp(file_path, stamp_path)
      out_path = Rails.root.join('tmp', 'pdfs', "#{SecureRandom.uuid}.pdf")
      stamp = CombinePDF.load(stamp_path).pages[0]
      original = CombinePDF.load(file_path)
      original.pages.each { |page| page << stamp }
      original.save out_path
      out_path
    rescue => e
      Rails.logger.error "Failed to datestamp PDF file: #{e.message}"
      raise
    ensure
      File.delete(stamp_path) if File.exist?(stamp_path)
    end
  end
end
