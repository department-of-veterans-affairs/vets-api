# frozen_string_literal: true

module AppealsApi
  class DecisionReviewReport
    attr_reader :from, :to

    FAULTY_STATUSES = %w[error].freeze

    def initialize(from: nil, to: nil)
      @from = from
      @to = to
    end

    def hlr_by_status_and_count
      group_records(HigherLevelReview)
    end

    def faulty_hlr
      @faulty_hlr ||= HigherLevelReview.where(created_at: from..to, status: FAULTY_STATUSES)
    end

    def nod_by_status_and_count
      group_records(NoticeOfDisagreement)
    end

    def faulty_nod
      @faulty_nod ||= NoticeOfDisagreement.where(created_at: from..to, status: FAULTY_STATUSES)
    end

    def evidence_submission_by_status_and_count
      group_records(EvidenceSubmission)
    end

    def faulty_evidence_submission
      @faulty_evidence_submission ||= EvidenceSubmission.errored.where(created_at: from..to)
    end

    def no_faulty_records?
      faulty_hlr.empty? && faulty_nod.empty?
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
