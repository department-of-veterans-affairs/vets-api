# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'lighthouse/benefits_intake/service'
require 'benefits_intake_service/utilities/convert_to_pdf'
require 'lighthouse/benefits_intake/metadata'
require 'pdf_utilities/pdf_validator'

module BenefitsIntakeService
  ##
  # Proxy Service for the Lighthouse Claims Intake API Service.
  # We are using it here to submit claims that cannot be auto-established,
  # via paper submission (electronic PDF submission to CMP)
  #
  # @deprecated Please use BenefitsIntake::Service instead
  # This class is maintained for backward compatibility but will be removed in the future.
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    # Forward declaration to ensure the embedded constants are available
    class InvalidDocumentError < StandardError; end

    REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze
    PDF_VALIDATOR_OPTIONS = {
      size_limit_in_bytes: 100_000_000, # 100 MB
      check_page_dimensions: true,
      check_encryption: true,
      width_limit_in_inches: 78,
      height_limit_in_inches: 101
    }.freeze

    def initialize(with_upload_location: false)
      ActiveSupport::Deprecation.new.warn(
        'BenefitsIntakeService::Service is deprecated. ' \
        'Please use BenefitsIntake::Service instead.'
      )
      super()
      @benefits_intake_service = BenefitsIntake::Service.new
      if with_upload_location
        upload_return = get_location_and_uuid
        @uuid = upload_return[:uuid]
        @location = upload_return[:location]
      end
    end

    # Validate a file satisfies Benefits Intake specifications. File must be a PDF.
    # @param [String] doc_path
    def validate_document(doc_path:)
      @benefits_intake_service.validate_document(doc_path:)
    end

    ##
    # Validate a file satisfies BenefitsIntake specifications.
    # ** File must be a PDF.
    #
    # @raise [InvalidDocumentError] if document is not a valid pdf
    # @see PDF_VALIDATOR_OPTIONS
    #
    # @param [String] document: path to file
    #
    # @returns [String] path to file
    #
    def valid_document?(document:)
      result = PDFUtilities::PDFValidator::Validator.new(document, PDF_VALIDATOR_OPTIONS).validate
      raise InvalidDocumentError, "Invalid Document: #{result.errors}" unless result.valid_pdf?

      response = validate_document(doc_path: document)
      raise InvalidDocumentError, "Invalid Document: #{response}" unless response.success?

      document
    end

    def upload_form(main_document:, attachments:, form_metadata:)
      raise 'Ran Method without Instance Variables' if @location.blank?

      metadata = generate_metadata(form_metadata)
      upload_doc(
        upload_url: @location,
        file: main_document,
        metadata: metadata.to_json,
        attachments:
      )
    end

    delegate :get_upload_location, to: :@benefits_intake_service

    delegate :get_bulk_status_of_uploads, to: :@benefits_intake_service

    delegate :get_file_path_from_objs, to: :@benefits_intake_service

    def generate_metadata(metadata)
      metadata_to_convert = {
        veteranFirstName: metadata[:veteran_first_name],
        veteranLastName: metadata[:veteran_last_name],
        fileNumber: metadata[:file_number],
        zipCode: metadata[:zip],
        source: metadata[:source] || 'va.gov submission',
        docType: metadata[:doc_type],
        businessLine: metadata[:business_line] || 'CMP',
        claimDate: metadata[:claim_date]
      }
      BenefitsIntake::Metadata.validate(metadata_to_convert.stringify_keys)
    end

    def generate_tmp_metadata_file(metadata)
      Common::FileHelpers.generate_clamav_temp_file(metadata.to_s, "#{SecureRandom.hex}.benefits_intake.metadata.json")
    end

    # Instantiates a new location and uuid via lighthouse
    def get_location_and_uuid
      upload_return = get_upload_location
      {
        uuid: upload_return.body.dig('data', 'id'),
        location: upload_return.body.dig('data', 'attributes', 'location')
      }
    end

    def get_upload_docs(file_with_full_path:, metadata:, attachments: [])
      @benefits_intake_service.get_upload_docs(
        file_with_full_path:,
        metadata:,
        attachments:
      )
    end

    def upload_doc(upload_url:, file:, metadata:, attachments: [])
      @benefits_intake_service.upload_doc(
        upload_url:,
        file:,
        metadata:,
        attachments:
      )
    end

    def upload_deletion_logic(file_with_full_path:, attachments:)
      @benefits_intake_service.upload_deletion_logic(
        file_with_full_path:,
        attachments:
      )
    end

    # Overload in other services to define files not meant to be deleted
    delegate :permanent_file?, to: :@benefits_intake_service

    # For methods not explicitly defined, delegate to the lighthouse implementation
    def method_missing(method_name, *, &)
      if @benefits_intake_service.respond_to?(method_name)
        @benefits_intake_service.send(method_name, *, &)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @benefits_intake_service.respond_to?(method_name, include_private) || super
    end
  end
end
