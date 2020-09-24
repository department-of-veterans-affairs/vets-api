# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReviewCleanUpWeekOldPii, type: :job do
  describe '#perform' do
    it 'removes PII for HigherLevelReviews that reached a completed status a week ago' do
      create :higher_level_review, :completed_a_week_ago
      expect(AppealsApi::HigherLevelReview.has_pii).not_to be_empty
      described_class.new.perform
      expect(AppealsApi::HigherLevelReview.has_pii).to be_empty
    end

    it 'does not log to sentry if there was nothing to work on' do
      expect(AppealsApi::HigherLevelReview.has_pii).to be_empty
      worker = described_class.new
      expect(worker).not_to receive(:log_message_to_sentry)
      worker.perform
    end

    it 'logs to sentry if no pii was removed /but/ some should have been' do
      allow_any_instance_of(described_class).to(
        receive(:no_higher_level_reviews_are_ready_to_have_pii_expunged?).and_return(false)
      )
      worker = described_class.new
      expect(worker).to receive(:log_message_to_sentry)
      worker.perform
    end
  end
end
