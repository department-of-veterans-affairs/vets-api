# frozen_string_literal: true

require 'logging/third_party_transaction'

module EVSS
  module DisabilityCompensationForm
    class SubmitForm8940 < Job
      extend Logging::ThirdPartyTransaction::MethodWrapper

      STATSD_KEY_PREFIX = 'worker.evss.submit_form8940'

      # Sidekiq has built in exponential back-off functionality for retries
      # A max retry attempt of 16 will result in a run time of ~48 hours
      # This job is invoked from 526 background job
      RETRY = 16

      sidekiq_options retry: RETRY

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

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

        ::Rails.logger.warn(
          'Submit Form 8940 Retries exhausted',
          { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
        )
      rescue => e
        ::Rails.logger.error(
          'Failure in SubmitForm8940#sidekiq_retries_exhausted',
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

      attr_accessor :submission_id

      wrap_with_logging(
        :upload_to_vbms,
        additional_class_logs: {
          action: 'upload form 8940 to EVSS'
        },
        additional_instance_logs: {
          submission_id: %i[submission_id]
        }
      )

      def get_docs(submission_id)
        @submission_id = submission_id
        { type: '21-8940', file: EVSS::DisabilityCompensationForm::Form8940Document.new(submission) }
      end

      # Performs an asynchronous job for generating and submitting 8940 PDF documents to VBMS
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        @submission_id = submission_id
        Sentry.set_tags(source: '526EZ-all-claims')

        super(submission_id)

        with_tracking('Form8940 Submission', submission.saved_claim_id, submission_id) do
          upload_to_vbms
        end
      rescue => e
        # Cannot move job straight to dead queue dynamically within an executing job
        # raising error for all the exceptions as sidekiq will then move into dead queue
        # after all retries are exhausted
        retryable_error_handler(e)
        raise e
      end

      private

      def document
        @document ||= EVSS::DisabilityCompensationForm::Form8940Document.new(submission)
      end

      def upload_to_vbms
        client.upload(document.file_body, document.data)
      ensure
        # Delete the temporary PDF file
        File.delete(document.pdf_path) if document.pdf_path.present?
      end

      def client
        @client ||= if Flipper.enabled?(:disability_compensation_lighthouse_document_service_provider)
                      # TODO: create client from lighthouse document service
                    else
                      EVSS::DocumentsService.new(submission.auth_headers)
                    end
      end
    end
  end
end
