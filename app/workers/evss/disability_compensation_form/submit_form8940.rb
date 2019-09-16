# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm8940 < Job
      STATSD_KEY_PREFIX = 'worker.evss.submit_form8940'

      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 10 will result in a run time of ~8 hours
      # This job is invoked from 526 background job
      RETRY = 10

      sidekiq_options retry: RETRY

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        Rails.logger.send(
          :error,
          "Failed all retries on SubmitForm8940 submit, last error: #{msg['error_message']}"
        )
        Metrics.new(STATSD_KEY_PREFIX, msg['jid']).increment_exhausted
      end

      # Performs an asynchronous job for generating and submitting 8940 PDF documents to VBMS
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        super(submission_id)

        with_tracking('Form8940 Submission', submission.saved_claim_id, submission_id) do
          document = EVSS::DisabilityCompensationForm::Form8940Document.new(submission)
          upload_to_vbms(submission.auth_headers, document)
        end
      rescue => error
        # Cannot move job straight to dead queue dynamically within an executing job
        # raising error for all the exceptions as sidekiq will then move into dead queue
        # after all retries are exhausted
        retryable_error_handler(error)
        raise error
      end

      private

      def upload_to_vbms(auth_headers, document)
        client = EVSS::DocumentsService.new(auth_headers)
        client.upload(document.file_body, document.data)
      ensure
        # Delete the temporary PDF file
        File.delete(document.pdf_path) if document.pdf_path.present?
      end
    end
  end
end
