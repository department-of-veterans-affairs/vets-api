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

    # If add_file_key is true the file is added to the returned hash as the parent key.  Useful for the rake task vba_documents:inspect_pdf
    def initialize(pdf:, add_file_key:  false)
      raise ArgumentError.new("Invalid file #{pdf}, does not exist!") unless File.exist? pdf
      @file = pdf
      @pdf_data = inspect_pdf(add_file_key)
    end

    def to_s
      inspect
    end

    def inspect_pdf(add_file_key)
      @parts = VBADocuments::MultipartParser.parse(@file)
      data = Hash.new
      parts_metadata = JSON.parse(@parts['metadata'])
      source = parts_metadata['source']
      data[SOURCE_KEY] = source
      data[DOC_TYPE_KEY] = parts_metadata['docType'] || 'Unknown'

      # read the PDF content
      parts_content = PdfInfo::Metadata.read(@parts['content'])
      doc_page_total = parts_content.pages
      data[:page_count] = doc_page_total
      data[:total_documents] = 1
      data[:total_pages] = doc_page_total
      content = {}
      data[:content] = content

      # get the dimensions
      doc_dim = parts_content.page_size_inches
      content[:dimensions] = doc_dim
      content[:oversized_pdf] = doc_dim[:height] >= 21 || doc_dim[:width] >= 21

      # check if this PDF has attachments
      attachment_names = @parts.keys.select { |k| k.match(/attachment\d+/) }
      content[:attachments] = [] unless attachment_names.empty?

      attachment_names.each do |att|
        attach_content = PdfInfo::Metadata.read(@parts[att])
        attach_dim = attach_content.page_size_inches
        attach_dim[:height] = attach_dim[:height].round(2)
        attach_dim[:width] = attach_dim[:width].round(2)
        attach_pages = attach_content.pages

        attach_data = Hash.new
        attach_data[:page_count] = attach_pages
        attach_data[:dimensions] = attach_dim
        attach_data[:oversized_pdf] = attach_dim[:height] >= 21 || attach_dim[:width] >= 21
        content[:attachments] << attach_data
        doc_page_total += attach_pages
      end
      content[:total_pages] = doc_page_total
      content[:total_documents] = attachment_names.size + 1
      return {@file => data} if add_file_key
      data
    end
  end
end

=begin
load './modules/vba_documents/lib/vba_documents/pdf_inspector.rb'
inspector = VBADocuments::PDFInspector.new(pdf: './test_files/0d8f95d1-567a-4801-84e9-62b2fad59bef')
inspector = VBADocuments::PDFInspector.new(pdf: './test_files/209b706f-c290-47b9-bae4-498bd44c7f3d')
=end
