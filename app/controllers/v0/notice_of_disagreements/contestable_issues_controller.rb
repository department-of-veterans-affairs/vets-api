# frozen_string_literal: true

module V0
  module NoticeOfDisagreements
    class ContestableIssuesController < AppealsBaseController
      def index
        render json: decision_review_service
          .get_notice_of_disagreement_contestable_issues(user: current_user)
          .body
      rescue => e
        log_exception_to_personal_information_log e, error_class: "#{self.class.name}#index exception #{e.class} (NOD)"
        raise
      end
    end
  end
end
