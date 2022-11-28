# frozen_string_literal: true

class AppealsApi::V2::DecisionReviews::HigherLevelReviews::ContestableIssuesController < AppealsApi::V1::DecisionReviews::BaseContestableIssuesController # rubocop:disable Layout/LineLength
  # This is overwritten so that we can more correctly format errors from caseflow when we get a 404 - all other
  # behavior should match the original method in BaseContestableIssuesController.
  def index
    get_contestable_issues_from_caseflow
    if caseflow_response_has_a_body_and_a_status?
      if caseflow_response.status == 404
        render json: {
          errors: [
            {
              title: 'Not found',
              detail: 'Appeals data for a veteran with that SSN was not found',
              code: 'CASEFLOWSTATUS404',
              status: '404'
            }
          ]
        }, status: :not_found
      else
        render_response(caseflow_response)
      end
    else
      render_unusable_response_error
    end
  end

  private

  def decision_review_type
    'higher_level_reviews'
  end
end
