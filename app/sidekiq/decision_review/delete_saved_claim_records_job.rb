# frozen_string_literal: true

require 'sidekiq'

module DecisionReview
  class DeleteSavedClaimRecordsJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this periodically
    sidekiq_options retry: false

    def perform
      return unless enabled?

      ::SavedClaim.where(delete_date: ..DateTime.now).destroy_all
    end

    private

    def enabled?
      Flipper.enabled? :decision_review_delete_saved_claims_job_enabled
    end
  end
end
