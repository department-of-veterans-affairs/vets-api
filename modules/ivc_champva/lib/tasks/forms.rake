# frozen_string_literal: true

PDFTK_HOMEBREW_PATH = '/opt/homebrew/bin/pdftk' unless defined?(PDFTK_HOMEBREW_PATH)
PDFTK_LOCAL_PATH    = '/usr/local/bin/pdftk' unless defined?(PDFTK_LOCAL_PATH)
MODELS_PATH = 'modules/ivc_champva/app/models/ivc_champva'
MAPPINGS_PATH = 'modules/ivc_champva/app/form_mappings'

namespace :ivc_champva do
  task :generate, [:form_path] => :environment do |_, args|
    file_path = args[:form_path]

    reader = if File.exist?(PDFTK_HOMEBREW_PATH)
               PdfForms.new(PDFTK_HOMEBREW_PATH)
             else
               PdfForms.new(PDFTK_LOCAL_PATH)
             end

    form_name = file_path.split('/').last.split('.').first

    new_model_file = Rails.root.join(MODELS_PATH, "#{form_name}.rb")

    meta_data = reader.get_field_names(file_path).map do |field|
      { pdf_field: field, data_type: 'String', attribute: field.split('.').last.split('[').first }
    end

    metadata_method = <<-METADATA
    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_file_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code') || '00000',
        'country' => @data.dig('veteran', 'address', 'country') || 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'uuid' => @uuid,
        'primaryContactInfo' => @data.dig('primary_contact_info')
      }
    end
    METADATA

    track_user_identity_method = <<-TRACK_USER_CONFIG
      def track_user_identity
        # Add STATS_KEY to top of file
        # Copy other data from 10-10D
      end
    TRACK_USER_CONFIG

    method_missing_method = <<-METHOD_MISSING
    def method_missing(_, *args)
      args&.first
    end
    METHOD_MISSING

    respond_to_missing_method = <<-RESPOND_METHOD_MISSING
    def respond_to_missing?(_)
      true
    end
    RESPOND_METHOD_MISSING

    File.open(new_model_file, 'w') do |f|
      f.puts '# frozen_string_literal: true'
      f.puts ''
      f.puts 'module IvcChampva'
      f.puts "  class #{form_name.upcase.gsub('_', '')}"
      f.puts '    include Virtus.model(nullify_blank: true)'
      f.puts ''
      f.puts '    attribute :data'

      # Attributes are not yet needed. Their advantage is that they provide datatypes that can manipulated such as
      # formatting dates. This is also a bit overkill for only central mail
      # meta_data.each do |field|
      #   f.puts "    attribute :#{field[:attribute].underscore}"
      # end

      f.puts ''
      f.puts '    def initialize(data)'
      f.puts '      @data = data,'
      f.puts "      @uuid = #{SecureRandom.uuid}"
      f.puts '    end'

      f.puts ''

      f.puts metadata_method

      f.puts track_user_identity_method

      f.puts method_missing_method

      f.puts respond_to_missing_method

      f.puts '  end'
      f.puts 'end'
    end

    puts "Created #{new_model_file}"

    # create the form mapping file
    mapping_file = Rails.root.join(MAPPINGS_PATH, "#{form_name}.json.erb")
    File.open(mapping_file, 'w') do |f|
      f.puts '{'
      meta_data.each_with_index do |field, index|
        puts field.inspect
        f.print "  \"#{field[:pdf_field]}\": \"<%= data.dig('#{field[:attribute]}') %>"
        f.puts "\"#{index + 1 == meta_data.size ? '' : ','}"
      end
      f.puts '}'
    end

    puts "Created #{mapping_file}"
  end
end

namespace :ivc_champva do
  # This task can be used when there's a new version of a form's PDF
  task :generate_mapping, [:form_path] => :environment do |_, args|
    file_path = args[:form_path]

    reader = if File.exist?(PDFTK_HOMEBREW_PATH)
               PdfForms.new(PDFTK_HOMEBREW_PATH)
             else
               PdfForms.new(PDFTK_LOCAL_PATH)
             end

    form_name = file_path.split('/').last.split('.').first
    # rubocop:disable Layout/LineLength
    update_test_msg = "\e[41;30mIMPORTANT: Don't forget to update the form OMB expiration unit test found in modules/ivc_champva/spec/models/#{form_name}_spec.rb\e[0m"
    # rubocop:enable Layout/LineLength

    meta_data = reader.get_field_names(file_path).map do |field|
      { pdf_field: field, data_type: 'String', attribute: field.split('.').last.split('[').first }
    end

    # Read the existing mapping file and compare keynames. If we have the same
    # quantity + names, then a new mapping file is not needed.
    old_file = Rails.root.join(MAPPINGS_PATH, "#{form_name}.json.erb")
    old_keys = JSON.parse(File.read(old_file)).keys
    new_keys = meta_data.map { |el| el[:pdf_field] }

    difference = old_keys - new_keys | new_keys - old_keys

    if difference.empty?
      puts "\e[42;30mNew mapping file would not result in any changes. Skipping.\e[0m"
      puts update_test_msg
      return
    end

    puts "\e[43;30mThe following keys are different between old/new mapping:\e[0m"
    puts difference
    puts "--\nCreating mapping file..."

    # create the form mapping file
    mapping_file = Rails.root.join(MAPPINGS_PATH, "#{form_name}_latest.json.erb")
    File.open(mapping_file, 'w') do |f|
      f.puts '{'
      meta_data.each_with_index do |field, index|
        puts field.inspect
        f.print "  \"#{field[:pdf_field]}\": \"<%= data.dig('#{field[:attribute]}') %>"
        f.puts "\"#{index + 1 == meta_data.size ? '' : ','}"
      end
      f.puts '}'
    end

    puts "\n"
    puts "\e[42;30mCreated #{mapping_file}\e[0m"
    puts update_test_msg
    puts "\n"
  end
end
