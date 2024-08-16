# frozen_string_literal: true

require 'common/file_helpers'

module PDFUtilities
  PDFTK = PdfForms.new(Settings.binaries.pdftk)

  class DatestampPdf

    attr_reader :file_path

    def initialize(file_path, append_to_stamp: nil)
      @file_path = file_path
      @append_to_stamp = append_to_stamp
    end

    def run(settings)
      settings = default_settings.merge(settings)
      settings.each do |key, value|
        instance_variable_set("@#{key}", value)
      end

      stamp_path = Common::FileHelpers.random_file_path

      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        if page_number.present? && template.present?
          reader = PDF::Reader.new(template)
          page_number.times do
            pdf.start_new_page
          end
          (pdf.draw_text stamp_text, at: [x, y], size:)
          (pdf.draw_text timestamp.strftime('%Y-%m-%d %I:%M %p %Z'), at: [x, y - 12], size:)
          (reader.page_count - page_number).times do
            pdf.start_new_page
          end
        else
          pdf.draw_text stamp_text, at: [x, y], size:
        end
      end

      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      if multistamp
        PDFUtilities::PDFTK.multistamp(file_path, stamp_path, out_path)
      else
        PDFUtilities::PDFTK.stamp(file_path, stamp_path, out_path)
      end

      out_path
    rescue => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path)
    end

    private

    attr_reader :text, :x, :y, :text_only, :size, :timestamp, :page_number, :template, :multistamp

    def default_settings
      {
        text: 'VA.gov',
        x: 5,
        y: 5,
        text_only: false,
        size: 10,
        timestamp: Time.zone.now,
        page_number: nil,
        template: nil,
        multistamp: false
      }.freeze
    end

    def timestamp4010007
      Date.strptime(timestamp.strftime('%m/%d/%Y'), '%m/%d/%Y')
    end

    def stamp_text
      @stamp_text ||= do
        stamp = text
        unless text_only
           stamp += if File.basename(@file_path) == 'vba_40_10007-stamped.pdf'
                    " #{I18n.l(timestamp4010007, format: :pdf_stamp4010007)}"
                  else
                    " #{I18n.l(timestamp, format: :pdf_stamp_utc)}"
                  end
          stamp += ". #{@append_to_stamp}" if @append_to_stamp
        end
        stamp
      end
    end

  end
end
