# frozen_string_literal: true

require 'fileutils'

# With a `@file` that must be a PDF (run the ConvertToPDF task before this if necessary)
# add a stamp (by default, includes the date) to the PDF at provided coordinates.
#
# When added as part of a document upload workflow,
# > run Workflow::Task::Shared::DatestampPdfTask, text: 'Vets.gov', x: 0, y: 0
# would add a stamp of "Vets.gov 2017-01-01 00:00:00" in the bottom left
# > run Workflow::Task::Shared::DatestampPdfTask, text: 'Vets.gov Submission', x: 449, y: 730, text_only: true
# would add a stamp near the top-right without a datetime of 'Vets.gov Submission'
#
# Each file can also have a custom bit of text added after using the `append_to_stamp` option when passed into
# the file upload args. Using the 'Vets.gov' workflow above:
# > ThingUploader.new(append_to_stamp: 'something-extra').start!(file)
# would add a stamp of "Vets.gov 2017-01-01 00:00:00 something-extra" in the bottom left

module Workflow::Task::Shared
  class DatestampPdfTask < Workflow::Task::ShrineFile::Base
    def run(settings)
      FileUtils.mkdir_p(Rails.root.join('tmp', 'pdfs'))
      in_path = get_file
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

    def get_file
      Common::FileHelpers.generate_temp_file(@file.read)
    end

    def generate_stamp(stamp_path, text, x, y, text_only)
      unless text_only
        text += ' ' + I18n.l(DateTime.current, format: :pdf_stamp) unless data[:skip_date_on_stamp]
        text += ('. ' + data[:append_to_stamp]) if data[:append_to_stamp]
      end

      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
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
      PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, out_path)
      File.delete(file_path)
      out_path
    rescue => e
      File.delete(out_path) if out_path && File.exist?(out_path)
      FileUtils.rmdir(out_dir) if out_dir && Dir.exist?(out_dir)
      Rails.logger.error "Failed to datestamp PDF file: #{e.message}"
      raise
    end
  end
end
