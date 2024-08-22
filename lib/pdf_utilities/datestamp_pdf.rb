# frozen_string_literal: true

require 'common/file_helpers'

# Utility classes and functions for VA PDF
module PDFUtilities
  # @see https://github.com/jkraemer/pdf-forms
  PDFTK = PdfForms.new(Settings.binaries.pdftk)

  # add a watermark datestamp to an existing pdf
  class DatestampPdf
    # prepare to datestamp an existing pdf document
    #
    # @param file_path [String]
    # @param append_to_stamp [String] text to append to the stamp
    #
    def initialize(file_path, append_to_stamp: nil)
      @file_path = file_path
      @append_to_stamp = append_to_stamp
    end

    # create a datestamped pdf copy of `file_path`
    #
    # @param settings [Hash] options for generating the datestamp
    # @option settings [String] :text the stamp text
    # @option settings [String] :x stamp x coordinate; default 5
    # @option settings [String] :y stamp y coordinate; default 5
    # @option settings [String] :text_only only stamp the provided text, no timestamp; default false
    # @option settings [String] :size font size; default 10
    # @option settings [String] :timestamp the timestamp to include; default Time.zone.now
    # @option settings [String] :page_number on which page to place the stamp; default nil
    # @option settings [String] :template another pdf on which to base the stamped pdf; default nil
    # @option settings [String] :multistamp apply stamped pdf page to corresponding input pdf; default false
    #
    # @return [String] path to generated stamped pdf
    #
    def run(settings)
      settings = default_settings.merge(settings)
      settings.each do |key, value|
        instance_variable_set("@#{key}", value)
      end

      generate_stamp
      stamp_pdf
    rescue => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      Common::FileHelpers.delete_file_if_exists(stamped_pdf)
      raise
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path)
    end

    private

    attr_reader :text, :x, :y, :text_only, :size, :page_number, :template, :multistamp, :file_path, :append_to_stamp,
                :stamp_path, :stamped_pdf

    # @see #run
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

    # reader for timestamp, ensure there is always a value
    def timestamp
      @timestamp ||= Time.zone.now
    end

    # format timestamp as :pdf_stamp4010007
    def timestamp4010007
      Date.strptime(timestamp.strftime('%m/%d/%Y'), '%m/%d/%Y')
    end

    # generate the stamp/background pdf
    # @see https://www.rubydoc.info/github/sandal/prawn/Prawn/Document
    def generate_stamp
      @stamp_path = Common::FileHelpers.random_file_path
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

      stamp_path
    end

    # create the stamp text to be used
    def stamp_text
      stamp = text
      unless text_only
        stamp += if File.basename(file_path) == 'vba_40_10007-stamped.pdf'
                   " #{I18n.l(timestamp4010007, format: :pdf_stamp4010007)}"
                 else
                   " #{I18n.l(timestamp, format: :pdf_stamp_utc)}"
                 end
        stamp += ". #{append_to_stamp}" if append_to_stamp
      end

      stamp
    end

    # combine the input and background pdfs into the stamped_pdf
    # @see https://www.pdflabs.com/docs/pdftk-man-page/#dest-op-stamp
    def stamp_pdf
      @stamped_pdf = "#{Common::FileHelpers.random_file_path}.pdf"
      if multistamp
        PDFUtilities::PDFTK.multistamp(file_path, stamp_path, stamped_pdf)
      else
        PDFUtilities::PDFTK.stamp(file_path, stamp_path, stamped_pdf)
      end

      stamped_pdf
    end

    # DatestampPdf class
  end
end
