# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    module JobTracking
      extend ActiveSupport::Concern

      def with_tracking(submission_id)
        yield
        job_success(submission_id)
      rescue => error
        job_error(submission_id, error)
        raise error
      end

      def job_success(submission_id)
        DisabilityCompensationJobStatus.upsert(
          { job_id: SecureRandom.uuid },
          disability_compensation_submission_id: submission_id,
          job_class: klass,
          status: 'success',
          updated_at: Time.now.utc
        )
      end

      def job_error(submission_id, error)
        DisabilityCompensationJobStatus.upsert(
          { job_id: self.jid },
          disability_compensation_submission_id: submission_id,
          job_id: jid,
          job_class: klass,
          status: 'error',
          error_message: error.message,
          args: self.args
        )
      end

      def klass
        self.class.name.demodulize
      end
    end
  end
end
