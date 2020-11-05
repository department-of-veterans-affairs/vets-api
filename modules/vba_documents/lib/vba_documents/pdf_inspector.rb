require 'vba_documents/multipart_parser'
require 'pdf_info'

module VBADocuments
  class PDFInspector
    attr_accessor :file, :pdf_data

    def initialize(pdf:)
      raise ArgumentError.new("Invalid file #{pdf}, does not exist!") unless File.exist? pdf
      @file = pdf
      @pdf_data = inspect_pdf
    end

    def total_documents
      @pdf_data[:total_documents]
    end

    def total_pages
      @pdf_data[:total_pages]
    end

    def doc_type
      @pdf_data[:doc_type]
    end

    def inspect
      @pdf_data.inspect
    end

    def to_s
      inspect
    end

    def inspect_pdf
      parts = VBADocuments::MultipartParser.parse(@file)
      data = Hash.new
      data[:tempfile] = parts['content'].path
      parts_metadata = JSON.parse(parts['metadata'])
      source = parts_metadata['source']
      data[:source] = source
      data[:doc_type] = parts_metadata['docType'] || 'Unknown'

      # read the PDF content
      parts_content = PdfInfo::Metadata.read(parts['content'])
      doc_page_total = parts_content.pages
      data[:page_count] = doc_page_total
      data[:total_documents] = 1
      data[:total_pages] = doc_page_total

      # get the dimensions
      doc_dim = parts_content.page_size_inches
      data[:dimensions] = doc_dim
      data[:offending_pdf] = doc_dim[:height] >= 21 || doc_dim[:width] >= 21

      # check if this PDF has attachments
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      data[:attachments] = [] unless attachment_names.empty?

      attachment_names.each do |att|
        attach_content = PdfInfo::Metadata.read(parts[att])
        attach_dim = attach_content.page_size_inches
        attach_pages = attach_content.pages

        attach_data = Hash.new
        attach_data[:tempfile] = parts[att].path
        attach_data[:source] = source
        attach_data[:page_count] = attach_pages
        attach_data[:dimensions] = attach_dim
        attach_data[:offending_pdf] = attach_dim[:height] >= 21 || attach_dim[:width] >= 21
        data[:attachments] << attach_data
        doc_page_total += attach_pages
      end
      data[:total_pages] = doc_page_total
      data[:total_documents] = attachment_names.size + 1
      {@file => data}
    end
  end
end

=begin
load './modules/vba_documents/lib/vba_documents/pdf_inspector.rb'
inspector = VBADocuments::PDFInspector.new(pdf: './test_files/0d8f95d1-567a-4801-84e9-62b2fad59bef')
inspector = VBADocuments::PDFInspector.new(pdf: './test_files/209b706f-c290-47b9-bae4-498bd44c7f3d')
=end
