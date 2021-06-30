# frozen_string_literal: true

class AppealsApi::V1::DecisionReviews::HigherLevelReviews::ContestableIssuesController < AppealsApi::V1::DecisionReviews::BaseContestableIssuesController # rubocop:disable Layout/LineLength
  include AppealsApi::HeaderModification

  def index
    deprecate(response: response, link: AppealsApi::HeaderModification::V2_DEV_DOCS) if hlr_v2_live?

    get_contestable_issues_from_caseflow

    if caseflow_response_has_a_body_and_a_status?
      render_response(caseflow_response)
    else
      render_unusable_response_error
    end
  end

  private

  def decision_review_type
    'higher_level_reviews'
  end

  def hlr_v2_live?
    Settings.modules_appeals_api.documentation.path_enabled_flag
  end
end
