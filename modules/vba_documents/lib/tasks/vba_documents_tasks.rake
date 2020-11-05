# frozen_string_literal: true
require_relative '../vba_documents/pdf_inspector'
require 'yaml'

namespace :vba_documents do

  NO_PDF_DIR = <<~no_pdf_dir
      No PDF directory provided. Point pdf_dir to the directory with the PDF files to test against.
      Invoke as follows:
      rake vba_documents:inspect_pdf[/path/to/pdfs]
  no_pdf_dir

  # example `bundle exec rake vba_documents:inspect_pdf[path/to/pdf/directory]`
  desc "Inspects PDF documents and their attachments and records the metadata including 21x21 size violations"
  task :inspect_pdf, [:pdf_test_dir] => [:environment] do |_, args|
    pdf_test_dir = args[:pdf_test_dir]
    raise ArgumentError.new(NO_PDF_DIR) unless pdf_test_dir
    raise ArgumentError.new "The PDF directory, #{pdf_test_dir} is not a valid directory path" unless Dir.exist?(pdf_test_dir)
    files = Dir["#{pdf_test_dir}/*"]
    pdfs = []
    files.each do |f|
      begin
        inspector = VBADocuments::PDFInspector.new(pdf: f)
        pdfs << inspector.pdf_data
      rescue StandardError => msg
        pdfs << "The file #{f} is not a valid PDF. Error: #{msg.message}"
      end
    end
    puts pdfs.to_yaml
  end
end
