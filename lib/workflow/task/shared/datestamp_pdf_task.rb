# frozen_string_literal: true
require 'workflow/task/shrine_file/base'

require 'fileutils'
module Workflow::Task::Shared
  class DatestampPdfTask < Workflow::Task::ShrineFile::Base
    def run(settings)
      FileUtils.mkdir_p(Rails.root.join('tmp', 'pdfs'))
      in_path = @file.download.path
      stamp_path = Rails.root.join('tmp', 'pdfs', "#{SecureRandom.uuid}.pdf")
      generate_stamp(stamp_path, settings[:text], settings[:x], settings[:y], settings[:text_only])
      out_path = stamp(in_path, stamp_path)
      update_file(io: File.open(out_path))
    ensure
      File.delete(stamp_path) if stamp_path && File.exist?(stamp_path)
      if out_path && File.exist?(out_path)
        File.delete(out_path)
        FileUtils.rmdir(File.dirname(out_path))
      end
    end

    private

    def generate_stamp(stamp_path, text, x, y, text_only)
      unless text_only
        text = Time.now.utc.strftime("#{text} %FT%T%:z")
        text += ('. ' + data[:append_to_stamp]) if data[:append_to_stamp]
      end

      Prawn::Document.generate stamp_path do |pdf|
        pdf.draw_text text, at: [x, y], size: 10
      end
    rescue StandardError => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      raise
    end

    def stamp(file_path, stamp_path)
      out_dir = Rails.root.join('tmp', 'pdfs', SecureRandom.uuid)
      FileUtils.mkdir_p(out_dir)
      out_path = File.join(out_dir, @file.original_filename)
      stamp = CombinePDF.load(stamp_path).pages[0]
      original = CombinePDF.load(file_path)
      original.pages.each { |page| page << stamp }
      original.save out_path
      out_path
    rescue => e
      File.delete(out_path) if out_path && File.exist?(out_path)
      FileUtils.rmdir(out_dir) if out_dir && Dir.exist?(out_dir)
      Rails.logger.error "Failed to datestamp PDF file: #{e.message}"
      raise
    end
  end
end
