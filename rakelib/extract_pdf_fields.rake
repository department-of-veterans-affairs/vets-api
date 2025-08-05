# frozen_string_literal: true

require 'pdf_forms'

namespace :pdf do
  desc 'Extract PDF form field metadata and save them to a Ruby file. ' \
       'Used when adding a new form to PdfFill::Filler' \
       'Example: bundle exec rake pdf:extract_fields\[lib/pdf_fill/forms/pdfs/10-10EZ.pdf\]' \
       'generated file will be in lib/pdf_fill/forms/10-10EZ_field_data.json'
  task :extract_fields, [:pdf_path] => :environment do |_t, args|
    pdf_path = args[:pdf_path]

    unless pdf_path
      puts 'Usage: rake pdf:extract_fields[pdf_path]'
      exit 1
    end

    unless File.exist?(pdf_path)
      puts "Error: File '#{pdf_path}' does not exist."
      exit 1
    end

    # Extract filename without extension
    file_name = File.basename(pdf_path, File.extname(pdf_path))

    # Initialize PdfForms
    pdf_forms = PdfForms.new(Settings.binaries.pdftk)

    # Extract fields
    fields = pdf_forms.get_fields(pdf_path)

    # Map fields into a structured format
    fields_map = fields.map do |field|
      {
        key: field.name,
        question_text: field.name_alt,
        options: field.options,
        type: field.type
      }
    end

    # Pretty format the fields_map as a JSON-like string
    formatted_data = JSON.pretty_generate(fields_map)

    # Generate output file name
    output_file = "lib/pdf_fill/forms/#{file_name}_field_data.json"
    FileUtils.mkdir_p(File.dirname(output_file)) # Ensure directory exists

    # Write the extracted data to a file
    File.write(output_file, formatted_data)
    puts "✅ Extracted PDF fields saved to: #{File.expand_path(output_file)}"
  end
end
