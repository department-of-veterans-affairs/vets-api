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
    US_COUNTRY_CODES = %w[US USA].freeze
    FORM_SCHEMA_ID = '21-4142'
    LEGACY_FORM_CLASS_ID = '21-4142'
    FORM_CLASS_ID_2024 = '21-4142-2024'

    attr_reader :pdf_path, :request_body

    # @return [Pathname] the generated PDF path
    # @return [Hash] the generated request body

    def initialize(validate: true)
      validate_form4142 if validate
      @pdf_path = generate_stamp_pdf
      @request_body = {
        'document' => to_faraday_upload,
        'metadata' => generate_metadata
      }
    end

    def generate_stamp_pdf
      base_pdf = fill_form_template
      signed_pdf = add_signature_stamp(base_pdf)
      timestamped_pdf = add_vagov_timestamp(signed_pdf)
      add_vagov_submission_label(timestamped_pdf)
    end

    protected

    # Template method - subclasses can override to use 2024 version
    def generate_2024_version?
      false
    end

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

    private

    def fill_form_template
      PdfFill::Filler.fill_ancillary_form(
        form_data,
        pdf_identifier,
        selected_form_class_id
      )
    end

    def add_signature_stamp(pdf)
      return pdf unless needs_signature_stamp?

      # NOTE: 2024 form signature field can't be filled programmatically,
      # so we stamp the signature instead (same approach as standalone 4142)
      PDFUtilities::DatestampPdf.new(pdf).run(
        text: signature,
        x: 50,
        y: 560,
        text_only: true,
        size: 10,
        page_number: 1,
        template: pdf,
        multistamp: true,
        timestamp: ''
      )
    end

    def add_vagov_timestamp(pdf)
      PDFUtilities::DatestampPdf.new(pdf).run(
        text: 'VA.gov',
        x: 5,
        y: 5,
        timestamp: submission_date
      )
    end

    def add_vagov_submission_label(pdf)
      PDFUtilities::DatestampPdf.new(pdf).run(
        text: 'VA.gov Submission',
        x: 510,
        y: 775,
        text_only: true
      )
    end

    def needs_signature_stamp?
      signature.present? && selected_form_class_id == FORM_CLASS_ID_2024
    end

    def selected_form_class_id
      generate_2024_version? ? FORM_CLASS_ID_2024 : LEGACY_FORM_CLASS_ID
    end

    def to_faraday_upload
      Faraday::UploadIO.new(
        @pdf_path,
        Mime[:pdf].to_s
      )
    end

    def generate_metadata
      address = form_data['veteranAddress']
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
        metadata, zip_code_is_us_based: us_country_code?(address['country'])
      ).to_json
    end

    def signature
      return unless form_data['signatureDate'].present? && form_data['veteranFullName'].present?

      full_name = form_data['veteranFullName']

      name = [full_name['first'], full_name['middle'], full_name['last']].compact.join(' ')
      "/es/ #{name}"
    end

    def set_signature_date(incoming_data)
      incoming_data.merge({ SIGNATURE_DATE_KEY => received_date })
    end

    def received_date
      submission_date.strftime(SIGNATURE_TIMESTAMP_FORMAT)
    end

    def us_country_code?(country_code)
      US_COUNTRY_CODES.include?(country_code.to_s.upcase)
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
