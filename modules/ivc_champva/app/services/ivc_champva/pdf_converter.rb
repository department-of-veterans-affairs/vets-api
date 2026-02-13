# frozen_string_literal: true

module IvcChampva
  class PdfConverter
    def initialize(uploaded_file)
      @uploaded_file = uploaded_file
    end

    ##
    # Converts an uploaded file to PDF format using ImageMagick.
    # Returns the path to the converted PDF file.
    #
    # @return [String] Path to the converted PDF file
    def convert_to_pdf
      Common::ConvertToPdf.new(@uploaded_file).run
    rescue => e
      Rails.logger.error("IVC ChampVA Forms - Failed to convert file to PDF: #{e.message}")
      raise
    end

    ##
    # Converts an uploaded file to PDF format using ImageMagick.
    # Returns a Tempfile with the PDF contents, ready for use.
    #
    # @return [Tempfile] Tempfile containing the converted PDF, in binmode and rewound
    def convert_to_tempfile
      pdf_path = convert_to_pdf
      pdf_filename = @uploaded_file.original_filename.sub(/\.[^.]+\z/, '.pdf')

      tempfile = Tempfile.new([File.basename(pdf_filename, '.pdf'), '.pdf'])
      tempfile.binmode
      tempfile.write(File.read(pdf_path))
      tempfile.rewind

      tempfile
    ensure
      FileUtils.rm_f(pdf_path) if pdf_path && File.exist?(pdf_path)
    end
  end
end
