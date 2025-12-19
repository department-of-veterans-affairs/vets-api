# frozen_string_literal: true

require 'json'

namespace :pdf do
  desc 'Map fields from field_data.json to keys in Ruby file. ' \
       'Example: bundle exec rake pdf:map_fields_to_keys[lib/pdf_fill/forms/5655_field_data.json,lib/pdf_fill/forms/va5655.rb]'
  task :map_fields_to_keys, [:json_file, :ruby_file] => :environment do |_t, args|
    json_file = args[:json_file]
    ruby_file = args[:ruby_file]

    unless json_file && ruby_file
      puts 'Usage: rake pdf:map_fields_to_keys[json_file,ruby_file]'
      puts 'Example: rake pdf:map_fields_to_keys[lib/pdf_fill/forms/5655_field_data.json,lib/pdf_fill/forms/va5655.rb]'
      exit 1
    end

    unless File.exist?(json_file)
      puts "Error: JSON file '#{json_file}' not found."
      puts 'To generate, run: `bundle exec rails "pdf:extract_fields[lib/pdf_fill/forms/pdfs/form_title.pdf]"`'
      exit 1
    end

    unless File.exist?(ruby_file)
      puts "Error: Ruby file '#{ruby_file}' does not exist."
      exit 1
    end

    # Read field data from JSON
    field_data = JSON.parse(File.read(json_file))
    
    # Load the Ruby file to get KEY constant
    file_path = File.expand_path(ruby_file)
    load file_path
    
    # Extract the form class name and get KEY from it
    form_class_name = File.basename(ruby_file, '.rb').split('_').map(&:capitalize).join
    form_class = PdfFill::Forms.const_get(form_class_name)
    key_hash = form_class::KEY
    
    # Normalize a key by replacing iterator indices with %iterator%
    normalize_key = lambda do |key_str|
      # Replace all [number] patterns with [%iterator%]
      key_str.to_s.gsub(/\[(\d+)\]/, '[%iterator%]')
    end
    
    # Strip all iterator patterns and indices from a key for comparison
    strip_iterators = lambda do |key_str|
      key_str.to_s
        .gsub(/\[%iterator%\]/, '')  # Remove [%iterator%]
        .gsub(/\[(\d+)\]/, '')       # Remove [0], [1], etc.
    end
    
    # Check if two keys match (handling iterator patterns)
    keys_match = lambda do |key1, key2, use_stripped = false|
      return true if key1.to_s == key2.to_s
      # Try normalized comparison
      return true if normalize_key.call(key1) == normalize_key.call(key2)
      # Only try stripped comparison if requested (fallback)
      if use_stripped
        return true if strip_iterators.call(key1) == strip_iterators.call(key2)
      end
      false
    end
    
    # Recursively find a key in the KEY hash by matching the PDF key
    find_key_in_hash = lambda do |hash_obj, target_key, path = [], use_stripped = false|
      hash_obj.each do |key, value|
        current_path = path + [key]
        
        if value.is_a?(Hash)
          # Check if this hash has a 'key' field that matches
          pdf_key = value[:key] || value['key']
          if pdf_key
            # Try exact match or normalized match (handles iterator patterns)
            if keys_match.call(pdf_key, target_key, use_stripped)
              return { found: true, path: current_path, value: value }
            end
          end
          
          # Recurse into nested hash
          result = find_key_in_hash.call(value, target_key, current_path, use_stripped)
          return result if result[:found]
        end
      end
      
      { found: false }
    end
    
    # Process each field from JSON
    matched_count = 0
    unmatched_fields = []
    
    field_data.each do |field|
      json_key = field['key']
      question_text = field['question_text'] || '(no question text)'
      
      # Try to find this key in the KEY hash (first without stripping)
      result = find_key_in_hash.call(key_hash, json_key)
      
      # If not found, try again with stripped iterators
      if !result[:found]
        result = find_key_in_hash.call(key_hash, json_key, [], true)
      end
      
      if result[:found]
        matched_count += 1
      else
        unmatched_fields << {
          key: json_key,
          question_text: question_text
        }
      end
    end
    
    # Print unmatched fields
    puts "\n" + '=' * 70
    puts "UNMATCHED FIELDS (#{unmatched_fields.length}):"
    puts '=' * 70
    puts
    
    if unmatched_fields.any?
      unmatched_fields.each_with_index do |field, index|
        puts "#{index + 1}. Key: #{field[:key]}"
        puts "   Question: #{field[:question_text]}"
        puts
      end
    else
      puts "All fields matched!"
      puts
    end
    
    puts '=' * 70
    puts "Summary:"
    puts "  Matched: #{matched_count}"
    puts "  Unmatched: #{unmatched_fields.length}"
    puts "  Total: #{field_data.length}"
    puts '=' * 70
    puts 'NOTE: these unmatched keys may be text titles in the form. Review the form manually to determine if this is the case.'
  end
end
