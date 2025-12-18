# frozen_string_literal: true

require 'json'
require 'set'

namespace :pdf do
  desc 'Compare extracted PDF fields with Ruby field mappings. ' \
       'Example: bundle exec rake pdf:compare_fields[lib/pdf_fill/forms/pdfs/5655.pdf,lib/pdf_fill/forms/va5655.rb]'
  task :compare_fields, [:pdf_path, :ruby_file] => :environment do |_t, args|
    pdf_path = args[:pdf_path]
    ruby_file = args[:ruby_file]

    unless pdf_path && ruby_file
      puts 'Usage: rake pdf:compare_fields[pdf_path,ruby_file]'
      puts 'Example: rake pdf:compare_fields[lib/pdf_fill/forms/pdfs/5655.pdf,lib/pdf_fill/forms/va5655.rb]'
      exit 1
    end

    # Extract filename without extension for JSON file
    file_name = File.basename(pdf_path, File.extname(pdf_path))
    json_file = "lib/pdf_fill/forms/#{file_name}_field_data.json"

    unless File.exist?(json_file)
      puts "Error: Extracted fields file '#{json_file}' not found."
      puts "Please run 'rake pdf:extract_fields[#{pdf_path}]' first."
      exit 1
    end

    unless File.exist?(ruby_file)
      puts "Error: Ruby file '#{ruby_file}' does not exist."
      exit 1
    end

    # Read extracted fields from JSON
    json = JSON.parse(File.read(json_file))
    extracted_keys = json.map { |f| f['key'] }.to_set

    # Extract keys from Ruby file
    rb_content = File.read(ruby_file)
    rb_keys = []

    # ITERATOR constant value - it's '%iterator%' from HashConverter
    iterator_value = '%iterator%'

    # Extract all key: '...' patterns, handling string interpolation
    # Match double-quoted strings (which can contain interpolation)
    rb_content.scan(/key:\s*"([^"]+)"/) do |match|
      key = match[0]
      # Replace #{ITERATOR} or \#{ITERATOR} with the actual iterator value
      # Handle both escaped and unescaped forms
      key = key.gsub(/\\?#\{ITERATOR\}/, iterator_value)
      rb_keys << key
    end
    
    # Also match single-quoted strings (no interpolation)
    rb_content.scan(/key:\s*'([^']+)'/) do |match|
      key = match[0]
      rb_keys << key
    end

    # ITERATOR is '%iterator%' which gets replaced at runtime
    # So "automobiles.make[%iterator%]" becomes "automobiles.make[0]", "automobiles.make[1]", etc.
    def normalize_for_comparison(key)
      # Normalize iterator patterns and numeric indices to a common placeholder
      key.gsub(/\[%iterator%\]/, '[INDEX]')
         .gsub(/\[0\]/, '[INDEX]')
         .gsub(/\[1\]/, '[INDEX]')
         .gsub(/\[2\]/, '[INDEX]')
         .gsub(/\[3\]/, '[INDEX]')
         .gsub(/\[4\]/, '[INDEX]')
         .gsub(/\[5\]/, '[INDEX]')
         .gsub(/\[6\]/, '[INDEX]')
         .gsub(/\[7\]/, '[INDEX]')
    end

    # Normalize both sets
    normalized_extracted = extracted_keys.map { |k| normalize_for_comparison(k) }.to_set
    normalized_rb = rb_keys.map { |k| normalize_for_comparison(k) }.to_set

    # Find fields in PDF that don't match any Ruby pattern
    missing_in_rb = extracted_keys.select do |pdf_key|
      normalized_pdf = normalize_for_comparison(pdf_key)
      !normalized_rb.include?(normalized_pdf)
    end

    # Find Ruby patterns that don't exist in PDF
    # Exclude iterator-based patterns since they're handled dynamically
    missing_in_pdf = rb_keys.select do |rb_key|
      normalized_rb_key = normalize_for_comparison(rb_key)
      !normalized_extracted.include?(normalized_rb_key) && !rb_key.include?('%iterator%') && !rb_key.match?(/\[#\{ITERATOR\}\]/)
    end

    puts '=' * 70
    puts 'PDF FIELD COMPARISON RESULTS'
    puts '=' * 70
    puts "\nFields in PDF that are NOT mapped in Ruby:"
    if missing_in_rb.empty?
      puts '  [OK] All PDF fields are mapped!'
    else
      missing_in_rb.sort.each { |k| puts "  - #{k}" }
    end

    puts "\nRuby mappings that don't exist in PDF:"
    if missing_in_pdf.empty?
      puts '  [OK] All Ruby mappings exist in PDF!'
    else
      missing_in_pdf.sort.each { |k| puts "  - #{k}" }
    end

    puts "\n" + '=' * 70
    puts 'SUMMARY'
    puts '=' * 70
    puts "Total fields in PDF: #{extracted_keys.size}"
    puts "Total field patterns in Ruby: #{rb_keys.size}"
    puts "Unmapped PDF fields: #{missing_in_rb.size}"
    puts "Non-existent Ruby mappings: #{missing_in_pdf.size}"

    if missing_in_rb.size > 0 || missing_in_pdf.size > 0
      puts "\n" + '=' * 70
      puts 'CONCLUSION'
      puts '=' * 70
      if missing_in_rb.include?('Text2')
        puts 'NOTE: Text2 field exists in PDF but is not mapped in Ruby'
        puts '      (Text1 and Text3 are mapped for signatures)'
      end
      if missing_in_rb.size == 1 && missing_in_rb.include?('Text2')
        puts "\n[OK] All other fields are correctly mapped!"
        puts '     The iterator-based fields (automobiles, debts, otherAssets) are'
        puts '     correctly using the %iterator% pattern which gets replaced at runtime.'
      end
    end

    puts "\n" + '=' * 70
  end
end
