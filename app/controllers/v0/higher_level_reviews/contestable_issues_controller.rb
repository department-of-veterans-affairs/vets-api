# frozen_string_literal: true

module V0
  module HigherLevelReviews
    class ContestableIssuesController < AppealsBaseController
      def index
        render json: decision_review_service
          .get_higher_level_review_contestable_issues(user: current_user, benefit_type: params[:benefit_type])
          .body
      end
    end
  end
end
