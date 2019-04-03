# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Base class for jobs involved in the 526 submission workflow.
    # Mixes in the JobStatus module so all sub-classes have automatic metrics and logging.
    #
    class Job
      include Sidekiq::Worker
      include JobStatus

      # Sub-classes should call super so that @submission id is available as an instance variable
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
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
