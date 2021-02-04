# frozen_string_literal: true

module AppealsApi
  class DecisionReviewReport
    def hlr_with_errors
      HigherLevelReview.where(created_at: from..to, status: 'error')
    end

    def nod_with_errors
      NoticeOfDisagreement.where(created_at: from..to, status: 'error')
    end
  end
end
