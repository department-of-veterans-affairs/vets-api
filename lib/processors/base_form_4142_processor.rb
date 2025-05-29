# frozen_string_literal: true

require 'pdf_fill/filler'
require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_utilities/datestamp_pdf'
require 'simple_forms_api_submission/metadata_validator'

module Processors
  class Form4142ValidationError < StandardError
    def initialize(errors)
      super
      @errors = errors
    end
  end

  class BaseForm4142Processor
    SIGNATURE_DATE_KEY = 'signatureDate'
    SIGNATURE_TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S'
    TIMEZONE = 'Central Time (US & Canada)'
    FORM_SCHEMA_ID = '21-4142'
    LEGACY_FORM_CLASS_ID = '21-4142'
    FORM_CLASS_ID_2024 = '21-4142-2024'

    # @return [Pathname] the generated PDF path
    # @return [Hash] the generated request body
    attr_reader :pdf_path, :request_body

    def initialize(validate: true)
      validate_form4142 if validate
      @pdf_path = generate_stamp_pdf
      @request_body = {
        'document' => to_faraday_upload,
        'metadata' => generate_metadata
      }
    end

    # Single entry point: choose the right form_class_id, then fill & stamp.
    def generate_stamp_pdf
      selected_form_class_id = generate_2024_version? ? FORM_CLASS_ID_2024 : LEGACY_FORM_CLASS_ID

      pdf = PdfFill::Filler.fill_ancillary_form(
        form_data,
        pdf_identifier,
        selected_form_class_id
      )

      # Handle signature stamping for 2024 version
      if signature.present? && selected_form_class_id == FORM_CLASS_ID_2024
        pdf = PDFUtilities::DatestampPdf.new(pdf).run(
          text: signature,
          x: 50,
          y: 560,
          text_only: true,
          size: 10,
          page_number: 1,
          template: pdf,
          multistamp: true,
          timestamp_required: false
        )
      end

      # Add VA.gov timestamp
      stamped_path = PDFUtilities::DatestampPdf.new(pdf).run(
        text: 'VA.gov',
        x: 5,
        y: 5,
        timestamp: submission_date
      )

      # Add VA.gov Submission text
      stamped_path = PDFUtilities::DatestampPdf.new(stamped_path).run(
        text: 'VA.gov Submission',
        x: 510,
        y: 775,
        text_only: true
      )
    end

    protected

    # Default: use legacy form
    def generate_2024_version?
      false
    end
    # Abstract methods to be implemented by subclasses
    def form_data
      raise NotImplementedError, 'Subclasses must implement form_data method'
    end

    def pdf_identifier
      raise NotImplementedError, 'Subclasses must implement pdf_identifier method'
    end

    def metadata_uuid
      raise NotImplementedError, 'Subclasses must implement metadata_uuid method'
    end

    def submission_date
      raise NotImplementedError, 'Subclasses must implement submission_date method'
    end

    def country_code_for_us_validation
      'US' # Default implementation, can be overridden
    end

    private

    def uuid
      @uuid ||= SecureRandom.uuid
    end

    def to_faraday_upload
      Faraday::UploadIO.new(
        @pdf_path,
        Mime[:pdf].to_s
      )
    end

    def generate_metadata
      address = form_data['veteranAddress']
      country_is_us = address['country'] == country_code_for_us_validation
      veteran_full_name = form_data['veteranFullName']

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form_data['vaFileNumber'] || form_data['veteranSocialSecurityNumber'],
        'receiveDt' => received_date,
        'uuid' => metadata_uuid,
        'zipCode' => address['postalCode'],
        'source' => 'VA Forms Group B',
        'hashV' => Digest::SHA256.file(@pdf_path).hexdigest,
        'numberAttachments' => 0,
        'docType' => FORM_SCHEMA_ID,
        'numberPages' => PDF::Reader.new(@pdf_path).pages.size
      }

      SimpleFormsApiSubmission::MetadataValidator.validate(
        metadata, zip_code_is_us_based: country_is_us
      ).to_json
    end

    def received_date
      submission_date.strftime(SIGNATURE_TIMESTAMP_FORMAT)
    end

    def set_signature_date(incoming_data)
      incoming_data.merge({ SIGNATURE_DATE_KEY => received_date })
    end

    def signature
      full_name = form_data.dig('veteranFullName')
      return unless form_data['signatureDate'].present? && full_name

      name = [full_name['first'], full_name['middle'], full_name['last']].compact.join(' ')
      "/es #{name}"
    end

    def validate_form4142
      return unless Flipper.enabled?(:form4142_validate_schema)

      schema = VetsJsonSchema::SCHEMAS[FORM_SCHEMA_ID]
      errors = JSON::Validator.fully_validate(schema, form_data, errors_as_objects: true)

      unless errors.empty?
        Rails.logger.error('Form 4142 failed validation', { errors: })
        raise Form4142ValidationError.new({ errors: })
      end
    end
  end
end
