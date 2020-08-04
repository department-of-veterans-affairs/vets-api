# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewCleanUpWeekOldPii
    include Sidekiq::Worker
    include SentryLogging

    def perform
      @updated_hlrs = HigherLevelReview.ready_to_have_pii_expunged.remove_pii

      return if pii_was_removed? || no_higher_level_reviews_are_ready_to_have_pii_expunged?

      log_message_to_sentry(
        'Failed to expunge PII from HigherLevelReviews (modules/appeals_api)',
        :error,
        ids: ids_of_higher_level_reviews_ready_to_have_pii_expunged
      )
    end

    private

    def pii_was_removed?
      @updated_hlrs.present?
    end

    def no_higher_level_reviews_are_ready_to_have_pii_expunged?
      ids_of_higher_level_reviews_ready_to_have_pii_expunged.empty?
    end

    def ids_of_higher_level_reviews_ready_to_have_pii_expunged
      @ids_of_higher_level_reviews_ready_to_have_pii_expunged ||=
        HigherLevelReview.ready_to_have_pii_expunged.pluck :id
    end
  end
end
