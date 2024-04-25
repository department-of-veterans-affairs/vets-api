# frozen_string_literal: true

module DebtsApi
  class V0::FsrRehydrationService
    include SentryLogging

    class UserDoesNotOwnsubmission < StandardError; end
    class NoInProgressFormDataStored < StandardError; end

    def self.attempt_rehydration(user_uuid:, submission_id:)
      submission = DebtsApi::V0::Form5655Submission.find(submission_id)

      raise NoInProgressFormDataStored unless submission.ipf_data
      raise UserDoesNotOwnsubmission unless submission.user_uuid == user_uuid

      submission.upsert_in_progress_form
    end
  end
end
