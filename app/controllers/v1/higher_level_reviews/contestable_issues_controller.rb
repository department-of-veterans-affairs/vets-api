# frozen_string_literal: true

module V1
  module HigherLevelReviews
    class ContestableIssuesController < AppealsBaseControllerV1
      def index
        render json: decision_review_service
          .get_higher_level_review_contestable_issues(user: current_user, benefit_type: params[:benefit_type])
          .body
      rescue => e
        log_exception_to_personal_information_log(
          e,
          error_class: "#{self.class.name}#index exception #{e.class} (HLR_V1)",
          benefit_type: params[:benefit_type]
        )
        raise
      end
    end
  end
end
