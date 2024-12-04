# frozen_string_literal: true

module SimpleFormsApi
  module Submission
    class MetadataValidator
      def self.validate(metadata, zip_code_is_us_based: true)
        validate_first_name(metadata)
          .then { |m| validate_last_name(m) }
          .then { |m| validate_file_number(m) }
          .then { |m| validate_zip_code(m, zip_code_is_us_based) }
          .then { |m| validate_source(m) }
          .then { |m| validate_doc_type(m) }
      end

      def self.validate_first_name(metadata)
        validate_presence_and_stringiness(metadata['veteranFirstName'], 'veteran first name')
        metadata['veteranFirstName'] =
          I18n.transliterate(metadata['veteranFirstName']).gsub(%r{[^a-zA-Z\-\/\s]}, '').strip.first(50)

        metadata
      end

      def self.validate_last_name(metadata)
        validate_presence_and_stringiness(metadata['veteranLastName'], 'veteran last name')
        metadata['veteranLastName'] =
          I18n.transliterate(metadata['veteranLastName']).gsub(%r{[^a-zA-Z\-\/\s]}, '').strip.first(50)

        metadata
      end

      def self.validate_file_number(metadata)
        validate_presence_and_stringiness(metadata['fileNumber'], 'file number')
        unless metadata['fileNumber'].match?(/^\d{8,9}$/)
          raise ArgumentError, 'file number is invalid. It must be 8 or 9 digits'
        end

        metadata
      end

      def self.validate_zip_code(metadata, zip_code_is_us_based)
        zip_code = metadata['zipCode']
        if zip_code_is_us_based
          validate_presence_and_stringiness(zip_code, 'zip code')
          zip_code = zip_code.dup.gsub(/[^0-9]/, '')
          zip_code.insert(5, '-') if zip_code.match?(/\A[0-9]{9}\z/)
          zip_code = '00000' unless zip_code.match?(/\A[0-9]{5}(-[0-9]{4})?\z/)
        else
          zip_code = '00000'
        end

        metadata['zipCode'] = zip_code

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
end
