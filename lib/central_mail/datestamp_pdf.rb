# frozen_string_literal: true

require 'common/file_helpers'

module CentralMail
  class DatestampPdf
    def initialize(file_path, append_to_stamp: nil)
      @file_path = file_path
      @append_to_stamp = append_to_stamp
    end

    def run(settings)
      stamp_path = Common::FileHelpers.random_file_path
      generate_stamp(stamp_path, settings[:text], settings[:x], settings[:y], settings[:text_only], settings[:size])
      stamp(@file_path, stamp_path)
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
    end

    # rubocop:disable Metrics/ParameterLists
    def generate_stamp(stamp_path, text, x, y, text_only, size = 10)
      unless text_only
        text += " #{I18n.l(Time.zone.now, format: :pdf_stamp)}"
        text += ". #{@append_to_stamp}" if @append_to_stamp
      end

      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        pdf.draw_text text, at: [x, y], size:
      end
    rescue => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      raise
    end
    # rubocop:enable Metrics/ParameterLists

    def stamp(file_path, stamp_path)
      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, out_path)
      File.delete(file_path)
      out_path
    rescue
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise
    end
  end
end
