# frozen_string_literal: true

require 'hexapdf'

require 'common/file_helpers'

# Utility classes and functions for VA PDF
module PDFUtilities
  # @see https://github.com/jkraemer/pdf-forms
  PDFTK = PdfForms.new(Settings.binaries.pdftk)

  # add a watermark datestamp to an existing pdf
  class PDFStamper
    include PDFUtilities::ExceptionHandling

    STAMP_SETS = {} # rubocop:disable Style/MutableConstant

    ##
    # Registers a stamp set with a specific identifier.
    #
    # @param identifier [String] The ID to register.
    # @param stamps [Array<Hash>] The set of stamps associated with the ID.
    #
    def self.register_stamps(identifier, stamps)
      STAMP_SETS[identifier] = stamps
    end

    # prepare to datestamp an existing pdf document
    def initialize(id, stamps: nil)
      @stamps = stamps || STAMP_SETS[id] || []
    end

    # stamp a generated pdf
    # if there is an error stamping the pdf, the original path is returned
    # - user uploaded attachments can be malformed
    #
    # @see PDFUtilites::DatestampPdf#run
    #
    # @param pdf_path [String] the path to a generated pdf; ie. claim.to_pdf
    #
    # @return [String] the path to the stamped pdf
    def run(pdf_path, timestamp: nil, append_to_stamp: nil)
      raise PdfMissingError, 'Original PDF is missing' unless File.exist?(pdf_path)

      # assigning all here to prevent error in rescue
      previous = stamp_path = stamped = pdf_path

      stamps.each do |stamp|
        previous = stamped

        stamp = default_settings.merge(stamp)
        stamp.each { |key, value| instance_variable_set("@#{key}", value) }

        @timestamp ||= timestamp || Time.zone.now
        @append_to_stamp ||= append_to_stamp

        stamp_path = generate_stamp
        stamped = stamp_pdf(previous, stamp_path)

        Common::FileHelpers.delete_file_if_exists(previous) unless previous == pdf_path
        Common::FileHelpers.delete_file_if_exists(stamp_path)
      end

      stamped
    rescue => e
      Common::FileHelpers.delete_file_if_exists(previous) unless previous == pdf_path
      Common::FileHelpers.delete_file_if_exists(stamped) unless stamped == pdf_path
      Common::FileHelpers.delete_file_if_exists(stamp_path)
      log_and_raise_error('Failed to generate datestamp file', e)
    ensure
      Common::FileHelpers.delete_file_if_exists(previous) unless previous == pdf_path
      Common::FileHelpers.delete_file_if_exists(stamp_path)
    end

    private

    attr_reader :stamps, :text, :text_only, :timestamp, :append_to_stamp, :x, :y, :font, :size, :page_number, :template, :multistamp

    # @see #run
    def default_settings
      {
        text: 'VA.gov',
        text_only: false,
        timestamp: nil,
        append_to_stamp: nil,
        x: 5,
        y: 5,
        font: 'Helvetica',
        size: 10,
        page_number: nil,
        template: nil,
        multistamp: false
      }.freeze
    end

    # generate the stamp/background pdf
    # @see https://www.rubydoc.info/github/sandal/prawn/Prawn/Document
    def generate_stamp
      stamp_path = "#{Common::FileHelpers.random_file_path}.pdf"

      HexaPDF::Composer.create(stamp_path) do |composer|
        if page_number.present? && template.present?
          raise PdfMissingError, "Template PDF missing: #{template}" unless File.exist?(template)

          reader = PDF::Reader.new(template)
          page_number.times { composer.new_page }

          composer.canvas.font(font, size:)
          composer.canvas.text(stamp_text, at: [x, y])
          composer.canvas.text(timestamp.strftime('%Y-%m-%d %I:%M %p %Z'), at: [x, y - 12])

          (reader.page_count - page_number).times { composer.new_page }
        else
          composer.canvas.font(font, size:)
          composer.canvas.text(stamp_text, at: [x, y])
        end
      end

      stamp_path
    rescue => e
      log_and_raise_error('Failed to generate stamp', e)
    end

    # create the stamp text to be used
    def stamp_text
      stamp = text
      unless text_only
        stamp += " #{I18n.l(timestamp, format: :pdf_stamp_utc)}"
        stamp += ". #{append_to_stamp}" if append_to_stamp
      end

      stamp
    end

    # combine the input and background pdfs into the stamped_pdf
    # @see https://www.pdflabs.com/docs/pdftk-man-page/#dest-op-stamp
    def stamp_pdf(pdf_path, stamp_path)
      Rails.logger.info("Stamping PDF: #{pdf_path} with stamp: #{stamp_path}")

      raise PdfMissingError, "Original PDF missing: #{pdf_path}" unless File.exist?(pdf_path)
      raise PdfMissingError, "Generated stamp missing: #{stamp_path}" unless File.exist?(stamp_path)

      stamped_pdf = "#{Common::FileHelpers.random_file_path}.pdf"

      if multistamp
        PDFUtilities::PDFTK.multistamp(pdf_path, stamp_path, stamped_pdf)
      else
        PDFUtilities::PDFTK.stamp(pdf_path, stamp_path, stamped_pdf)
      end

      raise StampGenerationError, 'Stamped PDF was not created' unless File.exist?(stamped_pdf)

      stamped_pdf
    rescue => e
      Common::FileHelpers.delete_file_if_exists(stamped_pdf)
      log_and_raise_error('Failed to generate stamp', e)
    end

  end
end
