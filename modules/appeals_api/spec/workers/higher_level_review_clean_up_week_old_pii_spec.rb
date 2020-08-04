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
  end
end
