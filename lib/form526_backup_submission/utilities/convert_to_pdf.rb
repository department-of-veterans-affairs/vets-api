# frozen_string_literal: true

require 'mini_magick'

module Form526BackupSubmission
  module Utilities
    class ConvertToPdf
      CAN_CONVERT = %w[.jpg .jpeg .png .gif .bmp .txt].freeze
      IMG_TYPES = %w[.jpg .jpeg .png .gif .bmp].freeze
      NON_IMG_TYPES = CAN_CONVERT - IMG_TYPES
      NOTE_PAGE = 'This PDF has been generated/converted by va.gov from a non-PDF document supplied by the end-user.
      This cover page has been auto-generated.
      The user\'s content begins on page #2.'

      attr_accessor :original_file, :original_filename, :converted_file, :converted_filename
      attr_reader :entropy

      def initialize(file)
        @original_file = file
        @original_filename = File.basename(@original_file)
        @entropy = "#{Common::FileHelpers.random_file_path}.#{Time.now.to_i}"
        @converted_filename = "#{@entropy}.converted_from_#{@original_filename}.pdf"
        extension = File.extname(@original_filename).downcase
        case extension
        when *IMG_TYPES
          convert_img!
        when *NON_IMG_TYPES
          convert_txt!
        else
          raise "Unsupported file type (#{extension}), cannot convert to PDF."
        end
      end

      private

      def generate_pdf_title_page
        NOTE_PAGE + "\n\nOriginal Filename: \"#{@original_filename}\"\nConverted DateTime: #{Time.zone.now}\n"
      end

      def generate_pdf_title_page_pdf
        tmp = "#{@entropy}.converted_from_#{@original_filename}_cover_page.pdf"
        Prawn::Document.generate(tmp) do |pdf|
          pdf.text generate_pdf_title_page
        end
        tmp
      end

      def convert_img!
        tmp_cover_page_pdf = generate_pdf_title_page_pdf
        convert = MiniMagick::Tool::Convert.new
        convert.resize('2550x3300') # 8.5x11 in pixels
        convert << '-density' << '300' # 300 dpi
        convert << tmp_cover_page_pdf # instruction doc (first page of resulting pdf)
        convert << @original_file # original filename (input)
        convert << @converted_filename # output filename (output)
        convert.call # do it
        # Delete tmp cover/info page for pdf after new file generated
        Common::FileHelpers.delete_file_if_exists(tmp_cover_page_pdf)
      end

      def convert_txt!
        # The default PDF fonts only supports 'Windows-1252' encoding.
        # We COULD download more fonts if we needed more char/unicode support.
        # But for now sending through with non-'Windows-1252' encoded chars stripped should work.
        # Can expand later if needed.
        content = File.read(@original_file).encode('Windows-1252', invalid: :replace, undef: :replace, replace: '')
        Prawn::Document.generate(@converted_filename) do |pdf|
          pdf.text generate_pdf_title_page
          pdf.start_new_page
          pdf.text content
        end
      end
    end
  end
end
