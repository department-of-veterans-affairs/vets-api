require_dependency 'vba_documents/multipart_parser'
require 'pdf_info'

# read all files in the test_files directory excluding this Ruby file
files = Dir.entries("./test_files").reject! {|f| File.directory? f }.reject!{|f| File.basename(__FILE__).eql?(f)}
puts "processing files: #{files.count}"
output = Hash.new
default = Hash.new.merge!({tempfile: '', dimensions: {}, offending_pdf: false})

files.each do |f|
  puts "Processing file: #{f}"
  data = default.clone
   parts = VBADocuments::MultipartParser.parse(f)
  # parts_metadata = JSON.parse(parts['metadata'])
  metadata = PdfInfo::Metadata.read(parts['content'])
  doc_info = metadata.page_size_inches
  data[:tempfile] = parts['content'].path
  data[:dimensions] = metadata.page_size_inches

  if doc_info[:height] >= 21 || doc_info[:width] >= 21
    data[:offending_pdf] = true
  end

  attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
  data[:attachments] = [] unless attachment_names.empty?

  attachment_names.each_with_index do |att, i|
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

p output

=begin
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
end
=end
