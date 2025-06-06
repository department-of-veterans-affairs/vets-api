# frozen_string_literal: true

require 'hexapdf'
require 'hexapdf/cli'

require 'common/file_helpers'

# Utility classes and functions for VA PDF
module PDFUtilities
  # add a watermark datestamp to an existing pdf using a set of established stamps
  class PDFStamper
    include PDFUtilities::ExceptionHandling

    # defined stamp sets to be used
    STAMP_SETS = {} # rubocop:disable Style/MutableConstant

    # Registers a stamp set with a specific identifier.
    #
    # @param identifier [String|Symbol] The ID to register.
    # @param stamps [Array<Hash>] The set of stamps associated with the ID.
    # => [{text: 'VA.GOV', x: 5, y: 5 }, {text: 'Test', x: 400, y: 700, text_only: true }, ... ]
    def self.register_stamps(identifier, stamps)
      STAMP_SETS[identifier] = stamps
    end

    # Retrieve a set of stamps; useful if needing to redefine properties based on a set
    #
    # @param identifier [String|Symbol] The ID of the set.
    #
    # @return [Array<Hash>] the stamp set or empty array if not registered
    def self.get_stamp_set(identifier)
      STAMP_SETS[identifier] || []
    end

    # prepare to datestamp an existing pdf document
    def initialize(id, stamps: nil)
      @stamps = stamps || PDFStamper.get_stamp_set(id)
    end

    # stamp a generated pdf
    #
    # @param pdf_path [String] the path to a generated pdf; ie. claim.to_pdf
    # @param timestamps [DateTime] timestamp to override what is defined in the stamps

    #
    # @return [String] the path to the stamped pdf
    def run(pdf_path, timestamp: nil, append_to_stamp: nil)
      raise PdfMissingError, 'Original PDF is missing' unless File.exist?(pdf_path)

      # assigning all here to prevent error in rescue
      previous = stamp_path = stamped = pdf_path

      stamps.each do |stamp|
        previous = stamped

        init_stamp(stamp, timestamp:, append_to_stamp:)

        stamp_path = generate_stamp
        stamped = stamp_pdf(previous, stamp_path)

        Common::FileHelpers.delete_file_if_exists(previous) unless previous == pdf_path
        Common::FileHelpers.delete_file_if_exists(stamp_path)
      end

      stamped
    rescue => e
      Common::FileHelpers.delete_file_if_exists(stamped) unless stamped == pdf_path
      log_and_raise_error('Failed to generate datestamp file', e)
    ensure
      Common::FileHelpers.delete_file_if_exists(previous) unless previous == pdf_path
      Common::FileHelpers.delete_file_if_exists(stamp_path)
    end

    private

    attr_reader :stamps, :text, :text_only, :timestamp, :append_to_stamp, :x, :y, :font, :size, :page_number,
                :template, :multistamp

    # establish the instance values for the current stamp
    def init_stamp(stamp, timestamp: nil, append_to_stamp: nil)
      stamp = default_settings.merge(stamp)
      stamp.each { |key, value| instance_variable_set("@#{key}", value) }

      @timestamp ||= timestamp || Time.zone.now
      @append_to_stamp ||= append_to_stamp
    end

    # @see #init_stamp
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
    # @see https://hexapdf.gettalong.org/documentation/api/HexaPDF/Composer.html
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
    # @see https://github.com/gettalong/hexapdf/blob/master/lib/hexapdf/cli/watermark.rb
    def stamp_pdf(pdf_path, stamp_path)
      Rails.logger.info("Stamping PDF: #{pdf_path} with stamp: #{stamp_path}")

      raise PdfMissingError, "Original PDF missing: #{pdf_path}" unless File.exist?(pdf_path)
      raise PdfMissingError, "Generated stamp missing: #{stamp_path}" unless File.exist?(stamp_path)

      stamped_pdf = "#{Common::FileHelpers.random_file_path}.pdf"

      reader = PDF::Reader.new(stamp_path)
      pages = multistamp ? [*1..reader.page_count].join(',') : '1'

      HexaPDF::CLI.run(['watermark', '-w', stamp_path, '-i', pages, '-t', 'stamp', pdf_path, stamped_pdf])

      raise StampGenerationError, 'Stamped PDF was not created' unless File.exist?(stamped_pdf)

      stamped_pdf
    rescue => e
      Common::FileHelpers.delete_file_if_exists(stamped_pdf)
      log_and_raise_error('Failed to generate stamp', e)
    end
  end
end
