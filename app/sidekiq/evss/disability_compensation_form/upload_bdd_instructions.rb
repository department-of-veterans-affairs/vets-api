# frozen_string_literal: true

require 'logging/third_party_transaction'

module EVSS
  module DisabilityCompensationForm
    class UploadBddInstructions < Job
      extend Logging::ThirdPartyTransaction::MethodWrapper

      STATSD_KEY_PREFIX = 'worker.evss.submit_form526_bdd_instructions'
      # 'Other Correspondence' document type
      BDD_INSTRUCTIONS_DOCUMENT_TYPE = 'L023'
      BDD_INSTRUCTIONS_FILE_NAME = 'BDD_Instructions.pdf'

      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id = msg['args'].first

        form_job_status = Form526JobStatus.find_by(job_id:)
        bgjob_errors = form_job_status.bgjob_errors || {}
        new_error = {
          "#{timestamp.to_i}": {
            caller_method: __method__.to_s,
            error_class:,
            error_message:,
            timestamp:,
            form526_submission_id:
          }
        }
        form_job_status.update(
          status: Form526JobStatus::STATUS[:exhausted],
          bgjob_errors: bgjob_errors.merge(new_error)
        )

        if Flipper.enabled?(:disability_compensation_use_api_provider_for_bdd_instructions)
          submission = Form526Submission.find(form526_submission_id)

          provider = api_upload_provider(submission)
          provider.log_uploading_job_failure(self, error_class, error_message)
        end

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

        ::Rails.logger.warn(
          'Submit Form 526 Upload BDD Instructions Retries exhausted',
          { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
        )
      rescue => e
        ::Rails.logger.error(
          'Failure in UploadBddInstructions#sidekiq_retries_exhausted',
          {
            messaged_content: e.message,
            job_id:,
            submission_id: form526_submission_id,
            pre_exhaustion_failure: {
              error_class:,
              error_message:
            }
          }
        )
        raise e
      end

      wrap_with_logging(
        :upload_bdd_instructions,
        additional_class_logs: {
          action: 'Upload BDD Instructions to EVSS'
        },
        additional_instance_logs: {
          submission_id: %i[submission_id]
        }
      )

      def self.api_upload_provider(submission)
        user = User.find(submission.user_uuid)

        ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:supplemental_document_upload],
          options: {
            form526_submission: submission,
            document_type: BDD_INSTRUCTIONS_DOCUMENT_TYPE,
            statsd_metric_prefix: STATSD_KEY_PREFIX
          },
          current_user: user,
          feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS
        )
      end

      # Submits a BDD instruction PDF in to EVSS
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        @submission_id = submission_id

        Sentry.set_tags(source: '526EZ-all-claims')
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
        if Flipper.enabled?(:disability_compensation_use_api_provider_for_bdd_instructions)
          provider = self.class.api_upload_provider(submission)

          upload_document = provider.generate_upload_document(BDD_INSTRUCTIONS_FILE_NAME)
          provider.submit_upload_document(upload_document, file_body)
        else
          EVSS::DocumentsService.new(submission.auth_headers).upload(file_body, document_data)
        end
      end

      def file_body
        @file_body ||= File.read('lib/evss/disability_compensation_form/bdd_instructions.pdf')
      end

      def retryable_error_handler(error)
        super(error)
        raise error
      end

      def document_data
        @document_data ||= EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          file_name: BDD_INSTRUCTIONS_FILE_NAME,
          tracked_item_id: nil,
          document_type: BDD_INSTRUCTIONS_DOCUMENT_TYPE
        )
      end
    end
  end
end
