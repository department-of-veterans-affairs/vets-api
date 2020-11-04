# frozen_string_literal: true

namespace :vba_documents do

  desc "Determines the PDF document and/or attachment violating the 21x21 validation error"
  task :upload_21x21_violations, [:pdf_dir] => [:environment] do |_, args|
    raise 'No test file directory provided. Point pdf_dir to the directory with the PDF files to test against.' unless args[:pdf_dir]
    pdf_dir = args[:pdf_dir]
    raise "The PDF directory, #{pdf_dir} is not a valid directory path" unless Dir.exist?(pdf_dir)
    files = Dir.entries(pdf_dir).select { |f| File.file? f }

    files.each do |f|
      puts f
    end
  end
end

