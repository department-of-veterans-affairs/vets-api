# frozen_string_literal: true

require 'logging/third_party_transaction'
require 'lighthouse/benefits_documents/form_526_lighthouse_documents_service'

module EVSS
  module DisabilityCompensationForm
    class UploadBddInstructions < Job
      extend Logging::ThirdPartyTransaction::MethodWrapper
      include BenefitsDocuments::Form526LighthouseDocumentsService

      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_bdd_instructions'
      FILE_NAME = 'BDD_Instructions.pdf'
      # 'Other Correspondence' Document Type:
      FILE_DOCUMENT_TYPE = 'L023'

      # retry for one day
      sidekiq_options retry: 14

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      # :nocov:
      sidekiq_retries_exhausted do |msg, _ex|
        job_exhausted(msg, STATSD_KEY_PREFIX)
      end
      # :nocov:

      wrap_with_logging(
        :upload_bdd_instructions,
        additional_class_logs: {
          action: 'Upload BDD Instructions to EVSS'
        },
        additional_instance_logs: {
          submission_id: %i[submission_id]
        }
      )

      # Submits a BDD instruction PDF in to EVSS
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        @submission_id = submission_id

        Raven.tags_context(source: '526EZ-all-claims')
        super(submission_id)

        with_tracking('Form526 Upload BDD instructions:', submission.saved_claim_id, submission.id) do
          upload_bdd_instructions
        end
      rescue => e
        # Can't send a job manually to the dead set.
        # Log and re-raise so the job ends up in the dead set and the parent batch is not marked as complete.
        retryable_error_handler(e)
      end

      private

      def upload_bdd_instructions
        user = User.find(submission.user_uuid)

        if Flipper.enabled?(:disability_compensation_lighthouse_document_service_provider, user)
          upload_lighthouse_document(file_body, FILE_NAME, submission, FILE_DOCUMENT_TYPE)
        else
          evss_client.upload(file_body, evss_document_data)
        end
      end

      def file_body
        @file_body ||= File.read('lib/evss/disability_compensation_form/bdd_instructions.pdf')
      end

      def evss_client
        @evss_client ||= EVSS::DocumentsService.new(submission.auth_headers)
      end

      def retryable_error_handler(error)
        super(error)
        raise error
      end

      def evss_document_data
        @evss_document_data ||= EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          file_name: FILE_NAME,
          tracked_item_id: nil,
          document_type: FILE_DOCUMENT_TYPE
        )
      end
    end
  end
end
