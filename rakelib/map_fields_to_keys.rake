# frozen_string_literal: true

require 'json'

namespace :pdf do
  desc 'Map fields from field_data.json to keys in Ruby file. ' \
       'Example: bundle exec rake pdf:map_fields_to_keys[lib/pdf_fill/forms/5655_field_data.json,\
       lib/pdf_fill/forms/va5655.rb]'
  task :map_fields_to_keys, %i[json_file ruby_file] => :environment do |_t, args|
    json_file = args[:json_file]
    ruby_file = args[:ruby_file]

    validate_arguments(json_file, ruby_file)
    validate_files_exist(json_file, ruby_file)

    field_data = load_field_data(json_file)
    key_hash = load_key_hash(ruby_file)

    matched_count, unmatched_fields = process_fields(field_data, key_hash)
    print_results(matched_count, unmatched_fields, field_data.length)
  end

  def validate_arguments(json_file, ruby_file)
    return if json_file && ruby_file

    puts 'Usage: rake pdf:map_fields_to_keys[json_file,ruby_file]'
    puts 'Example: rake pdf:map_fields_to_keys[lib/pdf_fill/forms/5655_field_data.json,lib/pdf_fill/forms/va5655.rb]'
    exit 1
  end

  def validate_files_exist(json_file, ruby_file)
    unless File.exist?(json_file)
      puts "Error: JSON file '#{json_file}' not found."
      puts 'To generate, run: `bundle exec rails "pdf:extract_fields[lib/pdf_fill/forms/pdfs/form_title.pdf]"`'
      exit 1
    end

    unless File.exist?(ruby_file)
      puts "Error: Ruby file '#{ruby_file}' does not exist."
      exit 1
    end
  end

  def load_field_data(json_file)
    JSON.parse(File.read(json_file))
  end

  def load_key_hash(ruby_file)
    file_path = File.expand_path(ruby_file)
    load file_path

    form_class_name = File.basename(ruby_file, '.rb').split('_').map(&:capitalize).join
    form_class = PdfFill::Forms.const_get(form_class_name)
    form_class::KEY
  end

  def normalize_key(key_str)
    key_str.to_s.gsub(/\[(\d+)\]/, '[%iterator%]')
  end

  def strip_iterators(key_str)
    key_str.to_s
           .gsub(/\[%iterator%\]/, '')
           .gsub(/\[(\d+)\]/, '')
  end

  def keys_match?(key1, key2, use_stripped: false)
    return true if key1.to_s == key2.to_s
    return true if normalize_key(key1) == normalize_key(key2)

    return true if use_stripped && strip_iterators(key1) == strip_iterators(key2)

    false
  end

  def find_key_in_hash(hash_obj, target_key, path = [], use_stripped: false)
    hash_obj.each do |key, value|
      current_path = path + [key]

      next unless value.is_a?(Hash)

      pdf_key = value[:key] || value['key']
      return { found: true, path: current_path, value: } if pdf_key && keys_match?(pdf_key, target_key, use_stripped)

      result = find_key_in_hash(value, target_key, current_path, use_stripped)
      return result if result[:found]
    end

    { found: false }
  end

  def find_matching_key(json_key, key_hash)
    result = find_key_in_hash(key_hash, json_key)
    return result if result[:found]

    find_key_in_hash(key_hash, json_key, [], use_stripped: true)
  end

  def process_fields(field_data, key_hash)
    matched_count = 0
    unmatched_fields = []

    field_data.each do |field|
      json_key = field['key']
      question_text = field['question_text'] || '(no question text)'

      result = find_matching_key(json_key, key_hash)

      if result[:found]
        matched_count += 1
      else
        unmatched_fields << {
          key: json_key,
          question_text:
        }
      end
    end

    [matched_count, unmatched_fields]
  end

  def print_results(matched_count, unmatched_fields, total_count)
    puts "\n#{'=' * 70}"
    puts "UNMATCHED FIELDS (#{unmatched_fields.length}):"
    puts '=' * 70

    if unmatched_fields.any?
      unmatched_fields.each_with_index do |field, index|
        puts "#{index + 1}. Key: #{field[:key]}"
        puts "   Question: #{field[:question_text]}"
        puts
      end
    else
      puts 'All fields matched!'
      puts
    end

    puts '=' * 70
    puts 'Summary:'
    puts "  Matched: #{matched_count}"
    puts "  Unmatched: #{unmatched_fields.length}"
    puts "  Total: #{total_count}"
    puts '=' * 70
    puts 'NOTE: unmatched keys may be text titles in the form. Review the form manually for confirmation.'
  end
end
