# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class UploadBddInstructions < Job
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_bdd_instructions'

      # retry for one day
      sidekiq_options retry: 14

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      # :nocov:
      sidekiq_retries_exhausted do |msg, _ex|
        job_exhausted(msg, STATSD_KEY_PREFIX)
      end
      # :nocov:

      # Submits a BDD instruction PDF in to EVSS
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        Raven.tags_context(source: '526EZ-all-claims')
        super(submission_id)
        with_tracking('Form526 Upload BDD instructions:', submission.saved_claim_id, submission.id) do
          file_body = File.read('lib/evss/disability_compensation_form/bdd_instructions.pdf')
          if Flipper.enabled?(:disability_compensation_lighthouse_document_service_provider)
            # TODO: create client from lighthouse document service
          else
            client = EVSS::DocumentsService.new(submission.auth_headers)
          end
          client.upload(file_body, create_document_data)
        end
      rescue => e
        # Can't send a job manually to the dead set.
        # Log and re-raise so the job ends up in the dead set and the parent batch is not marked as complete.
        retryable_error_handler(e)
      end

      private

      def retryable_error_handler(error)
        super(error)
        raise error
      end

      def create_document_data
        EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          file_name: 'BDD_Instructions.pdf',
          tracked_item_id: nil,
          document_type: 'L023' # 'Other Correspondence'
        )
      end
    end
  end
end
