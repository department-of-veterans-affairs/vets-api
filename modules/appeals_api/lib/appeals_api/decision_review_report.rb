# frozen_string_literal: true

module AppealsApi
  class DecisionReviewReport
    attr_reader :from, :to

    def initialize(from:, to:)
      @from = from
      @to = to
    end

    def hlr_by_status_and_count
      group_records(HigherLevelReview)
    end

    def hlr_with_errors
      HigherLevelReview.where(created_at: from..to, status: 'error')
    end

    def nod_by_status_and_count
      group_records(NoticeOfDisagreement)
    end

    def nod_with_errors
      NoticeOfDisagreement.where(created_at: from..to, status: 'error')
    end

    private

    def group_records(record_type)
      statuses = record_type::STATUSES.sort.index_with { |_| 0 }

      record_type
        .where(created_at: from..to)
        .group_by(&:status)
        .each { |status, record_list| statuses[status] = record_list.size }

      statuses
    end
  end
end
