# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewCleanUpWeekOldPii
    include Sidekiq::Worker

    def perform
      return unless enabled?

      AppealsApi::RemovePii.new(form_type: HigherLevelReview).run!
    end

    private

    def enabled?
      Flipper.enabled?(:decision_review_hlr_pii_expunge_enabled)
    end
  end
end
