# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Job
      include Sidekiq::Worker
      include JobStatus

      def perform(submission_id)
        @submission_id = submission_id
      end

      private

      def submission
        @submission ||= Form526Submission.find(@submission_id)
      end
    end
  end
end
