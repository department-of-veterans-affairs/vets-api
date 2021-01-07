# frozen_string_literal: true

module AppealsApi
  class DecisionReviewReport
    attr_reader :from, :to

    def initialize(from:, to:)
      @from = from
      @to = to
    end

    def successful_hlr_count
      HigherLevelReview.where(created_at: from..to, status: 'success').count
    end

    def hlr_with_errors
      HigherLevelReview.where(created_at: from..to, status: 'error')
    end

    def successful_nod_count
      NoticeOfDisagreement.where(created_at: from..to, status: 'success').count
    end

    def nod_with_errors
      NoticeOfDisagreement.where(created_at: from..to, status: 'error')
    end
  end
end
