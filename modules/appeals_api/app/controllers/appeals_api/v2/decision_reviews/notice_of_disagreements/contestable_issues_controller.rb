# frozen_string_literal: true

class AppealsApi::V2::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController < AppealsApi::V1::DecisionReviews::BaseContestableIssuesController # rubocop:disable Layout/LineLength
  private

  def decision_review_type
    'appeals' # notice of disagreement is `appeals` inside of Caseflow
  end
end
