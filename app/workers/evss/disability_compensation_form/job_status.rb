# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    module JobStatus
      extend ActiveSupport::Concern

      def with_tracking(job_title, saved_claim_id, submission_id)
        yield
        job_success(job_title, saved_claim_id, submission_id)
      rescue StandardError => error
        job_error(job_title, saved_claim_id, submission_id, error)
        raise error
      ensure
        job_try(job_title, saved_claim_id, submission_id)
      end

      def job_try(job_title, saved_claim_id, submission_id)
        Rails.logger.info(job_title,
                          'saved_claim_id' => saved_claim_id,
                          'submission_id' => submission_id,
                          'job_id' => jid,
                          'event' => 'try')
      end

      def job_success(job_title, saved_claim_id, submission_id)
        DisabilityCompensationJobStatus.upsert(
          { job_id: SecureRandom.uuid },
          disability_compensation_submission_id: submission_id,
          job_class: klass,
          status: 'success',
          updated_at: Time.now.utc
        )

        Rails.logger.info(job_title,
                          'saved_claim_id' => saved_claim_id,
                          'submission_id' => submission_id,
                          'job_id' => jid,
                          'event' => 'success')
      end

      def job_error(job_title, saved_claim_id, submission_id, error)
        DisabilityCompensationJobStatus.upsert(
          { job_id: jid },
          disability_compensation_submission_id: submission_id,
          job_id: jid,
          job_class: klass,
          status: 'error',
          error_message: error.message,
          updated_at: Time.now.utc
        )

        Rails.logger.error(job_title,
                           'saved_claim_id' => saved_claim_id,
                           'submission_id' => submission_id,
                           'job_id' => jid,
                           'event' => 'error',
                           'error_message' => error.message)
      end

      def klass
        self.class.name.demodulize
      end
    end
  end
end
