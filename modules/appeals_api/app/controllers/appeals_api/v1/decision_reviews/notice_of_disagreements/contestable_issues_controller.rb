# frozen_string_literal: true

class AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController < AppealsApi::V1::DecisionReviews::BaseContestableIssuesController # rubocop:disable Layout/LineLength

  def index
    #deprecate here
    get_contestable_issues_from_caseflow
    if caseflow_response_has_a_body_and_a_status?
      render_response(caseflow_response)
    else
      render_unusable_response_error
    end
  end

  private

  def decision_review_type
    'appeals' # notice of disagreement is `appeals` inside of Caseflow
  end
end
