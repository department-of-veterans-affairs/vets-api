# frozen_string_literal: true

require 'vba_documents/multipart_parser'
require 'pdf_info'

module VBADocuments
  class PDFInspector
    attr_accessor :file, :pdf_data, :parts

    module Constants
      DOC_TYPE_KEY = :doc_type
      SOURCE_KEY = :source
    end
    include Constants

    # If add_file_key is true the file is added to the returned hash as the parent key.
    # Useful for the rake task vba_documents:inspect_pdf
    # pdf can be a String file path or the parts result of 'VBADocuments::MultipartParser.parse(tempfile.path)'
    def initialize(pdf:, add_file_key: false)
      if pdf.is_a?(String)
        raise ArgumentError, "Invalid file #{pdf}, does not exist!" unless File.exist? pdf

        @file = pdf
        @parts = VBADocuments::MultipartParser.parse(@file)
      else
        @parts = pdf
      end
      begin
        @pdf_data = inspect_pdf(add_file_key)
      rescue => e
        Rails.logger.error "Failed to inspect pdf, #{e.message}.", backtrace: e.backtrace
        @pdf_data = { content: { failure: e.message } }
      end
    end

    def to_s
      inspect
    end

    def inspect_pdf(add_file_key)
      parts_metadata = JSON.parse(@parts['metadata'])

      # instantiate the data hash and set the source and doc_type
      data = { SOURCE_KEY => parts_metadata['source'], DOC_TYPE_KEY => parts_metadata['docType'] || 'Unknown',
               total_documents: 0, total_pages: 0, content: {} }

      # read the PDF content
      data[:content].merge!(read_pdf_metadata(@parts['content']))
      data[:content][:attachments] = []
      total_pages = data[:content][:page_count]
      total_documents = 1

      # check if this PDF has attachments
      attachment_names = @parts.keys.select { |k| k.match(/attachment\d+/) }

      attachment_names.each do |att|
        attach_data = read_pdf_metadata(@parts[att])
        total_pages += attach_data[:page_count]
        total_documents += 1
        data[:content][:attachments] << attach_data
      end
      data[:total_documents] = total_documents
      data[:total_pages] = total_pages
      return { @file => data } if add_file_key

      data
    end

    private

    def read_pdf_metadata(content_key)
      # read the PDF content
      parts_content = PdfInfo::Metadata.read(content_key)
      data_hash = {}
      data_hash[:page_count] = parts_content.pages

      # get and set the dimensions
      doc_dim = round_dimensions(parts_content.page_size_inches)
      doc_dim[:oversized_pdf] = doc_dim[:height] >= 21 || doc_dim[:width] >= 21
      data_hash[:dimensions] = doc_dim
      data_hash
    end

    def round_dimensions(dimensions)
      { height: dimensions[:height].round(2), width: dimensions[:width].round(2) }
    end
  end
end

# load './modules/vba_documents/lib/vba_documents/pdf_inspector.rb'
