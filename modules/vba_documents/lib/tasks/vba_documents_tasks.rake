# frozen_string_literal: true
require_relative '../vba_documents/pdf_inspector'
require 'yaml'

namespace :vba_documents do
  no_pdf = %{
No PDF directory provided. Point pdf_dir to the directory with the PDF files to test against.
Invoke as follows:
rake vba_documents:upload PDF_DIR= /path/to/pdfs
}
  desc "Determines the PDF document and/or attachment violating the 21x21 validation error"
  task :upload => [:environment] do
    pdf_dir =  ENV['PDF_DIR']
    raise ArgumentError.new no_pdf unless pdf_dir
    raise  ArgumentError.new "The PDF directory, #{pdf_dir} is not a valid directory path" unless Dir.exist?(pdf_dir)
    files = Dir["#{pdf_dir}/*"]
    pdfs = []
    files.each do |f|
      inspector = VBADocuments::PDFInspector.new(pdf: f)
      pdfs << inspector.pdf_data
    end
    puts pdfs.to_yaml
  end
end

