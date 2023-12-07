# frozen_string_literal: true

module SimpleFormsApiSubmission
  class MetadataValidator
    def self.validate(metadata)
      validate_first_name(metadata)
        .then { |m| validate_last_name(m) }
        .then { |m| validate_file_number(m) }
        .then { |m| validate_zip_code(m) }
        .then { |m| validate_source(m) }
        .then { |m| validate_doc_type(m) }
    end

    def self.validate_first_name(metadata)
      validate_presence_and_stringiness(metadata['veteranFirstName'], 'veteran first name')
      metadata['veteranFirstName'] =
        I18n.transliterate(metadata['veteranFirstName']).gsub(/[^a-zA-Z\-\s]/, '').strip.first(50)

      metadata
    end

    def self.validate_last_name(metadata)
      validate_presence_and_stringiness(metadata['veteranLastName'], 'veteran last name')
      metadata['veteranLastName'] =
        I18n.transliterate(metadata['veteranLastName']).gsub(/[^a-zA-Z\-\s]/, '').strip.first(50)

      metadata
    end

    def self.validate_file_number(metadata)
      validate_presence_and_stringiness(metadata['fileNumber'], 'file number')
      unless metadata['fileNumber'].match?(/^\d{8,9}$/)
        raise ArgumentError, 'file number is invalid. It must be 8 or 9 digits'
      end

      metadata
    end

    def self.validate_zip_code(metadata)
      validate_presence_and_stringiness(metadata['zipCode'], 'zip code')
      metadata['zipCode'] = '00000' unless metadata['zipCode'].match?(/\A\d{5}(-\d{4})?\z/)

      metadata
    end

    def self.validate_source(metadata)
      validate_presence_and_stringiness(metadata['source'], 'source')

      metadata
    end

    def self.validate_doc_type(metadata)
      validate_presence_and_stringiness(metadata['docType'], 'doc type')

      metadata
    end

    def self.validate_presence_and_stringiness(value, error_label)
      raise ArgumentError, "#{error_label} is missing" unless value
      raise ArgumentError, "#{error_label} is not a string" if value.class != String
    end
  end
end
