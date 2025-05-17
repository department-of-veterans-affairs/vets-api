# frozen_string_literal: true

require 'lighthouse/benefits_documents/worker_service'
require 'lighthouse/service_exception'
require 'pdf_utilities/datestamp_pdf'
require 'lighthouse/benefits_intake/service'
require 'common/exceptions/unprocessable_entity'
require 'persistent_attachment'

# Form 526 specific client service for the Lighthouse Benefits Documents API:
# https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current
#
# There is a similar service implemented in lib/lighthouse/benefits_documents/service.rb,
# however, its functionality is closely tied to the claims status tool.
#
# Uploads the supplied document metadata to the POST /services/benefits-documents/v1/documents
# Lighthouse endpoint
module BenefitsDocuments
  module Form526
    class UploadSupplementalDocumentService
      def self.call(*)
        new(*).call
      end

      # @param [String] file_body content of uploading file
      # @param [LighthouseDocument] lighthouse_document instance of wrapper class for document metadata
      def initialize(file_body, lighthouse_document)
        super()

        @file_body = file_body
        @lighthouse_document = lighthouse_document
      end

      # return [Faraday::Response] BenefitsDocuments::WorkerService makes http
      # calls with the Faraday gem under the hood
      def call
        # Validate document before uploading
        validate_document

        client = BenefitsDocuments::WorkerService.new
        client.upload_document(@file_body, @lighthouse_document)
      rescue => e
        # NOTE: third argument, lighthouse_client_id is left nil so it isn't logged.
        error = Lighthouse::ServiceException.send_error(
          e, self.class.to_s.underscore, nil, BenefitsDocuments::Configuration::DOCUMENTS_PATH
        )

        # Lighthouse::ServiceException can either raise an error or return an error object, so we need to
        # assign it to a variable and re-raise it here manually if it is the latter
        raise error
      end

      private

      def validate_document
        # Create temporary file to validate
        temp_file = Tempfile.new(['document', File.extname(@lighthouse_document.file_name)])
        temp_file.binmode
        temp_file.write(@file_body)
        temp_file.rewind

        extension = File.extname(@lighthouse_document.file_name)
        allowed_types = PersistentAttachment::ALLOWED_DOCUMENT_TYPES

        if allowed_types.exclude?(extension)
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: I18n.t('errors.messages.extension_allowlist_error', extension:,
                                                                        allowed_types:),
            source: 'BenefitsDocuments::Form526::UploadSupplementalDocumentService.validate_document'
          )
        elsif temp_file.size < PersistentAttachment::MINIMUM_FILE_SIZE
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: 'File size must not be less than 1.0 KB',
            source: 'BenefitsDocuments::Form526::UploadSupplementalDocumentService.validate_document'
          )
        end

        # Validate with Benefits Intake API
        document = PDFUtilities::DatestampPdf.new(temp_file.path).run(text: 'VA.GOV', x: 5, y: 5)
        intake_service = BenefitsIntake::Service.new
        intake_service.valid_document?(document:)
      rescue => e
        temp_file.close
        temp_file.unlink if temp_file.respond_to?(:unlink)
        raise e
      ensure
        temp_file.close
        temp_file.unlink if temp_file.respond_to?(:unlink)
      end
    end
  end
end
