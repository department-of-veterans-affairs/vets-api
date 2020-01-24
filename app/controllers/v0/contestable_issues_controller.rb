# frozen_string_literal: true

module V0
  class ContestableIssuesController < AppealsBaseController
    def index
      issues = decision_review_service.get_contestable_issues(current_user)
      render json: issues.body
    end
  end
end
