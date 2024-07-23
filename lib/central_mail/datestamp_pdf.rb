# frozen_string_literal: true

require 'common/file_helpers'
require 'pdf_fill/filler'

module CentralMail
  class DatestampPdf
    def initialize(file_path, append_to_stamp: nil)
      @file_path = file_path
      @append_to_stamp = append_to_stamp
    end

    def run(settings)
      stamp_path = Common::FileHelpers.random_file_path
      generate_stamp(stamp_path, settings[:text], settings[:x], settings[:y], settings[:text_only], settings[:size],
                     settings[:timestamp], settings[:page_number], settings[:template], @file_path)
      stamp(@file_path, stamp_path, multistamp: settings[:multistamp])
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
    end

    # rubocop:disable Metrics/ParameterLists
    # rubocop:disable Metrics/MethodLength
    def generate_stamp(stamp_path, text, x, y, text_only, size = 10, timestamp = nil, page_number = nil,
                       template = nil, file_path = nil)
      timestamp ||= Time.zone.now
      unless text_only
        text += if file_path == 'tmp/vba_40_10007-stamped.pdf'
                  " #{I18n.l(timestamp, format: :pdf_stamp4010007)}"
                else
                  " #{I18n.l(timestamp, format: :pdf_stamp_utc)}"
                end
        text += ". #{@append_to_stamp}" if @append_to_stamp
      end

      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        if page_number.present? && template.present?
          reader = PDF::Reader.new(template)
          page_number.times do
            pdf.start_new_page
          end
          (pdf.draw_text text, at: [x, y], size:)
          (pdf.draw_text timestamp.strftime('%Y-%m-%d %I:%M %p %Z'), at: [x, y - 12], size:)
          (reader.page_count - page_number).times do
            pdf.start_new_page
          end
        else
          pdf.draw_text text, at: [x, y], size:
        end
      end
    rescue => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      raise
    end
    # rubocop:enable Metrics/ParameterLists
    # rubocop:enable Metrics/MethodLength

    def stamp(file_path, stamp_path, multistamp: false)
      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      if multistamp
        PdfFill::Filler::PDF_FORMS.multistamp(file_path, stamp_path, out_path)
      else
        PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, out_path)
      end
      File.delete(file_path)
      out_path
    rescue
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise
    end
  end
end
