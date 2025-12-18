# frozen_string_literal: true

require 'json'

namespace :pdf do
  desc 'Add question_text from extracted PDF fields to Ruby KEY mappings. ' \
       'Example: bundle exec rake pdf:add_question_text[lib/pdf_fill/forms/pdfs/5655.pdf,lib/pdf_fill/forms/va5655.rb]'
  task :add_question_text, [:pdf_path, :ruby_file] => :environment do |_t, args|
    pdf_path = args[:pdf_path]
    ruby_file = args[:ruby_file]

    unless pdf_path && ruby_file
      puts 'Usage: rake pdf:add_question_text[pdf_path,ruby_file]'
      puts 'Example: rake pdf:add_question_text[lib/pdf_fill/forms/pdfs/5655.pdf,lib/pdf_fill/forms/va5655.rb]'
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
    
    # Read Ruby file for modification
    rb_content = File.read(ruby_file)
    new_content = rb_content.dup
    
    # Load the Ruby file to get KEY constant
    # Use load instead of eval so require_relative works correctly
    file_path = File.expand_path(ruby_file)
    load file_path
    
    # Extract the form class name and get KEY from it
    form_class_name = File.basename(ruby_file, '.rb').split('_').map(&:capitalize).join
    form_class = PdfFill::Forms.const_get(form_class_name)
    key_hash = form_class::KEY
    
    # Track updates
    added_count = 0
    skipped_count = 0
    
    # Helper: Find JSON entry by key, handling iterator patterns
    find_in_json = lambda do |key|
      # Try exact match first
      result = json.find { |field| field['key'] == key }
      return result if result
      
      # If key contains iterator pattern, try indexed versions
      if key.include?('%iterator%')
        (0..7).each do |i|
          indexed_key = key.gsub('%iterator%', i.to_s)
          result = json.find { |field| field['key'] == indexed_key }
          return result if result
        end
      end
      
      nil
    end
    
    
    # Recursively iterate through KEY hash (Ruby object from eval) and update the file content
    iterate_key = lambda do |key_hash_obj|
      key_hash_obj.each do |_k, v|
        next unless v.is_a?(Hash)
        
        # If this hash has a 'key' field, look it up in JSON
        if v[:key] || v['key']
          field_key = (v[:key] || v['key']).to_s
          
          # Check if question_text already exists in the object
          existing_question_text = v[:question_text] || v['question_text']
          
          # Look up in JSON (handles iterator patterns)
          json_field = find_in_json.call(field_key)
          
          if json_field && json_field['question_text']
            new_question_text = json_field['question_text']
            
            # Log if replacing existing question_text
            if existing_question_text && existing_question_text != new_question_text
              puts "\nReplacing question_text for key: #{field_key}"
              puts "  Old text: #{existing_question_text}"
              puts "  New text: #{new_question_text}"
            end
            
            # Update the object directly
            v[:question_text] = new_question_text
            
            # Write it back to the file using gsub
            escaped_key = Regexp.escape(field_key)
            escaped_text = new_question_text.gsub("'", "\\\\'")
            
            # Try to replace existing question_text first
            question_text_pattern = /(key:\s*["']#{escaped_key}["'][^\n]*\n)(\s*question_text:\s*["'])([^"']+)(["'])/m
            
            if new_content.match?(question_text_pattern)
              # Replace existing question_text
              new_content.gsub!(question_text_pattern) do |match|
                key_line = Regexp.last_match[1]
                question_text_prefix = Regexp.last_match[2]
                quote = Regexp.last_match[4]
                "#{key_line}#{question_text_prefix}#{escaped_text}#{quote}"
              end
            else
              # Add question_text if it doesn't exist
              key_pattern = /(^\s*key:\s*["']#{escaped_key}["'])(\s*,?\s*\n)/m
              new_content.gsub!(key_pattern) do |match|
                indent = match.match(/^(\s*)/)[1]
                has_comma = match.match?(/,/)
                key_part = match.match(/^\s*key:\s*["']#{escaped_key}["']/)[0]
                comma = has_comma ? '' : ','
                "#{key_part}#{comma}\n#{indent}question_text: '#{escaped_text}',\n"
              end
            end
            
            added_count += 1
          end
        else
          # Recurse into nested hash (still working with Ruby object)
          iterate_key.call(v)
        end
      end
    end
    
    iterate_key.call(key_hash)
    
    if added_count > 0
      # Create backup
      backup_file = "#{ruby_file}.backup.#{Time.now.to_i}"
      File.write(backup_file, rb_content)
      puts "Created backup: #{backup_file}"
      
      # Write updated content
      File.write(ruby_file, new_content)
      puts "Updated #{ruby_file}"
      puts "  Added question_text to #{added_count} fields"
      puts "  Skipped #{skipped_count} fields (already have question_text or no match found)"
      puts "\nNOTE: Please review the changes carefully."
      puts "      Backup saved to: #{backup_file}"
    else
      puts "No changes made. All fields either already have question_text or no matching PDF field found."
      puts "  Skipped #{skipped_count} fields"
    end
  end
end

