# frozen_string_literal: true

module V1
  module NoticeOfDisagreements
    class ContestableIssuesController < AppealsBaseControllerV1
      def index
        render json: decision_review_service
          .get_notice_of_disagreement_contestable_issues(user: current_user, benefit_type: params[:benefit_type])
          .body
      rescue => e
        log_exception_to_personal_information_log e,
                                                  error_class: "#{self.class.name}#index exception #{e.class} (NOD_V1)"
        raise
      end
    end
  end
end
