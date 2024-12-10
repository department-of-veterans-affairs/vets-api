# frozen_string_literal: true

require 'lighthouse/benefits_documents/worker_service'
require 'lighthouse/service_exception'

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
    end
  end
end
