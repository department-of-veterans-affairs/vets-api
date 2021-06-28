# frozen_string_literal: true

class AppealsApi::V2::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController < AppealsApi::V1::DecisionReviews::BaseContestableIssuesController # rubocop:disable Layout/LineLength
  private

  def decision_review_type
    'higher_level_reviews'
  end
end
