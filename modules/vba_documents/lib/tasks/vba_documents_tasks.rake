# frozen_string_literal: true

require_relative '../vba_documents/pdf_inspector'
require 'yaml'

namespace :vba_documents do
  NO_PDF_DIR = <<~NO_PDF_DIR
    No PDF directory provided. Point pdf_dir to the directory with the PDF files to test against.
    Invoke as follows:
    rake vba_documents:inspect_pdf[/path/to/pdfs]
  NO_PDF_DIR

  # example `bundle exec rake vba_documents:inspect_pdf[path/to/pdf/directory]`
  desc 'Inspects PDF documents and their attachments and records the metadata including 78x101 size violations'
  task :inspect_pdf, [:pdf_test_dir] => [:environment] do |_, args|
    pdf_test_dir = args[:pdf_test_dir]
    raise ArgumentError, NO_PDF_DIR unless pdf_test_dir
    unless Dir.exist?(pdf_test_dir)
      raise ArgumentError, "The PDF directory, #{pdf_test_dir} is not a valid directory path"
    end

    files = Dir["#{pdf_test_dir}/*"]
    pdfs = []
    files.each do |f|
      inspector = VBADocuments::PDFInspector.new(pdf: f, add_file_key: true)
      pdfs << inspector.pdf_data
    rescue => e
      pdfs << "The file #{f} is not a valid PDF. Error: #{e.message}"
    end
    puts pdfs.to_yaml
  end
end
