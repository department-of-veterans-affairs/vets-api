# frozen_string_literal: true

PDFTK_HOMEBREW_PATH = '/opt/homebrew/bin/pdftk'
PDFTK_LOCAL_PATH    = '/usr/local/bin/pdftk'
FORMS_API_MODELS_PATH = 'modules/forms_api/app/models/forms_api'
FORMS_API_MAPPINGS_PATH = 'modules/forms_api/app/form_mappings'

namespace :forms_api do
  task :generate, [:form_path] => :environment do |_, args|
    file_path = args[:form_path]

    reader = if File.exist?(PDFTK_HOMEBREW_PATH)
               PdfForms.new(PDFTK_HOMEBREW_PATH)
             else
               PdfForms.new(PDFTK_LOCAL_PATH)
             end

    form_name = file_path.split('/').last.split('.').first.camelize.gsub('-', '_')

    new_model_file = Rails.root.join(FORMS_API_MODELS_PATH, "#{form_name}.rb")

    meta_data = reader.get_field_names(file_path).map do |field|
      { pdf_field: field, data_type: 'String', attribute: field.split('.').last.split('[').first }
    end

    metadata_method = <<-METADATA
    def metadata(pdf_path)
      {
        "veteranFirstName"=> @data.dig('veteran_full_name', 'first'),
        "veteranLastName"=> @data.dig('veteran_full_name', 'last'),
        "fileNumber"=> @data['va_file_number'],
        "zipCode"=>"00000",
        "source"=>"va.gov",
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        "numberAttachments"=>0,
        "receiveDt"=> Time.zone.now.strftime('%Y-%m-%d %H:%M%S'),
        "numberPages"=> PdfInfo::Metadata.read(pdf_path).pages,
        "docType"=>"10182",
        "businessLine"=> @data['form_number'].split('_').first.upcase
      }
    end
    METADATA

    File.open(new_model_file, 'w') do |f|
      f.puts 'module FormsApi'
      f.puts "  class FormsApi::#{form_name.gsub('_', '')}"
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
      f.puts '      @data = data'
      f.puts '    end'

      f.puts ''

      f.puts metadata_method

      f.puts '  end'
      f.puts 'end'
    end

    puts "Created #{new_model_file}"

    # create the form mapping file
    mapping_file = Rails.root.join(FORMS_API_MAPPINGS_PATH, "#{form_name.downcase}.json.erb")
    File.open(mapping_file, 'w') do |f|
      f.puts '{'
      meta_data.each_with_index do |field, index|
        puts field.inspect
        f.print "  \"#{field[:pdf_field]}\": \"<%= data.dig( '#{field[:attribute]}') %>"
        f.puts "\"#{index + 1 == meta_data.size ? '' : ','}"
      end
      f.puts '}'
    end

    puts "Created #{mapping_file}"
  end
end
