# require_dependency 'vba_documents/multipart_parser'
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
      source = JSON.parse(parts['metadata'])['source']
      data[:source] = source

      # read the PDF content
      metadata = PdfInfo::Metadata.read(parts['content'])
      doc_page_total = metadata.pages
      data[:page_count] = doc_page_total
      data[:doc_count] = 1
      data[:total_pages] = doc_page_total

      # get the dimensions
      doc_info = metadata.page_size_inches
      data[:dimensions] = doc_info
      data[:offending_pdf] = doc_info[:height] >= 21 || doc_info[:width] >= 21

      # check if this PDF has attachments
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      data[:attachments] = [] unless attachment_names.empty?

      attachment_names.each do |att|
        attach_metadata = PdfInfo::Metadata.read(parts[att])
        attach_dim = attach_metadata.page_size_inches
        attach_pages = attach_metadata.pages

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
      data[:doc_count] = attachment_names.size + 1
      {@file => data}
    end

    private

    def parse_file
      parts = VBADocuments::MultipartParser.parse(@file)
      parts_metadata = JSON.parse(parts['metadata'])
      @source = parts_metadata['source'] # all other data is PII

      # read the PDF content
      @metadata = PdfInfo::Metadata.read(parts['content']) #metadata.pages
    end
  end
end

=begin
  # read all files in the test_files directory excluding this Ruby file
  files = Dir.entries("./test_files").reject! { |f| File.directory? f }.reject! { |f| File.basename(__FILE__).eql?(f) }
  files.map! do |f|
    "#{Rails.root}/test_files/#{f}"
  end
  puts "processing files: #{files.count}"
  output = Hash.new
  default = Hash.new.merge!({tempfile: '', dimensions: {}, offending_pdf: false})

  files.each do |f|
    puts "Processing file: #{f}"
    data = default.clone
    parts = VBADocuments::MultipartParser.parse(f)
    parts_metadata = JSON.parse(parts['metadata'])
    puts "parts_metadata: #{parts_metadata}" # get source all else is PII
    puts "******************** source= #{parts_metadata['source']}"

    metadata = PdfInfo::Metadata.read(parts['content']) #metadata.pages
    puts "content metadata: #{metadata}"
    doc_info = metadata.page_size_inches
    data[:tempfile] = parts['content'].path
    data[:dimensions] = metadata.page_size_inches

    if doc_info[:height] >= 21 || doc_info[:width] >= 21
      data[:offending_pdf] = true
    end

    attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
    data[:attachments] = [] unless attachment_names.empty? # change to if

    attachment_names.each do |att|
      attach_metadata = PdfInfo::Metadata.read(parts[att])
      doc_info = attach_metadata.page_size_inches
      attach_data = default.clone
      attach_data[:tempfile] = parts[att].path
      attach_data[:dimensions] = attach_metadata.page_size_inches

      if doc_info[:height] >= 21 || doc_info[:width] >= 21
        attach_data[:offending_pdf] = true
      end
      data[:attachments] << attach_data
    end

    output[f] = data
  end
end
p output

#=begin
parts = VBADocuments::MultipartParser.parse('/home/michael/Downloads/209b706f-c290-47b9-bae4-498bd44c7f3d')
puts "content: #{parts[DOC_PART_NAME]}"
metadata = PdfInfo::Metadata.read(parts[DOC_PART_NAME])
puts doc_info = metadata.page_size_inches
puts doc_info[:size][:height] >= 21 || doc_info[:size][:width] >= 21
attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
attachment_names.each_with_index do |att, i|
  puts "attachment: #{parts[att]}"
  metadata = PdfInfo::Metadata.read(parts[att])
  puts doc_info = metadata.page_size_inches
  puts doc_info[:size][:height] >= 21 || doc_info[:size][:width] >= 21

load './modules/vba_documents/lib/vba_documents/pdf_inspector.rb'
inspector = VBADocuments::PDFInspector.new(pdf: './test_files/0d8f95d1-567a-4801-84e9-62b2fad59bef')
inspector = VBADocuments::PDFInspector.new(pdf: './test_files/209b706f-c290-47b9-bae4-498bd44c7f3d')
s = inspector.to_s

=end
