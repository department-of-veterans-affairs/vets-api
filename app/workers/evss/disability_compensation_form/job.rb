# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Job
      include Sidekiq::Worker
      include JobStatus

      RETRY = 7

      sidekiq_options retry: RETRY

      sidekiq_retry_in do |count|
        # a government system backoff, retries a couple of times immediately
        # then less often in a 24hr period than the sidekiq default
        # given 7 retries: 1m(ish), 2m, 2h, 4h, 7h, 14h, 28h
        rand(60...90) if count <= 2
        (count**5.5) + 2.hours + rand(30) if count > 2
      end

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
