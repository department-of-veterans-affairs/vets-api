# frozen_string_literal: true

require 'logging/third_party_transaction'
require 'lighthouse/benefits_documents/worker_service'

module BenefitsDocuments
  module Form526LighthouseDocumentsService
    extend Logging::ThirdPartyTransaction::MethodWrapper

    wrap_with_logging(:upload_from_client)

    def upload_lighthouse_document(file_body, file_name, submission, document_type)
      user = User.find(submission.user_uuid)

      lighthouse_document = LighthouseDocument.new(
        claim_id: submission.submitted_claim_id,
        file_number: BenefitsDocuments::Service.new(user).file_number || user.ssn,
        document_type:,
        file_name:
      )

      raise Common::Exceptions::ValidationErrors, document_data unless lighthouse_document.valid?

      upload_from_client(user.icn, file_body, lighthouse_document)
    end

    private

    def upload_from_client(user_icn, file_body, lighthouse_document)
      client = BenefitsDocuments::WorkerService.new(user_icn)
      client.upload_document(file_body, lighthouse_document)
    end
  end
end
