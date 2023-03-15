# frozen_string_literal: true

module AppealsApi
  class DecisionReviewReport
    attr_reader :from, :to

    FAULTY_STATUSES = %w[error].freeze

    def initialize(from: nil, to: nil)
      @from = from
      @to = to
    end

    # HLR
    def hlr_by_status_and_count
      group_appeal_records(HigherLevelReview)
    end

    def faulty_hlr
      @faulty_hlr ||= HigherLevelReview.where(created_at: from..to, status: FAULTY_STATUSES).order(created_at: :desc)
    end

    def total_hlr_successes
      # HLRv1s final success status is "success", while HLRv2 is "complete", so we need to count on both
      @total_hlr_successes ||= lambda do
        sum = total_statuses_count(HigherLevelReview.v1, ['success'])
        sum += total_statuses_count(HigherLevelReview.v2, ['complete'])
        sum
      end.call
    end

    # NOD
    def nod_by_status_and_count
      group_appeal_records(NoticeOfDisagreement)
    end

    def faulty_nod
      @faulty_nod ||= NoticeOfDisagreement.where(created_at: from..to, status: FAULTY_STATUSES).order(created_at: :desc)
    end

    def total_nod_successes
      @total_nod_successes ||= total_statuses_count(NoticeOfDisagreement)
    end

    # SC
    def sc_by_status_and_count
      group_appeal_records(SupplementalClaim)
    end

    def faulty_sc
      @faulty_sc ||= SupplementalClaim.where(created_at: from..to, status: FAULTY_STATUSES).order(created_at: :desc)
    end

    def total_sc_successes
      @total_sc_successes ||= total_statuses_count(SupplementalClaim)
    end

    # Evidence submissions - NOD
    def evidence_submission_by_status_and_count
      group_evidence_submission_records(EvidenceSubmission, 'AppealsApi::NoticeOfDisagreement')
    end

    def faulty_evidence_submission
      @faulty_evidence_submission ||=
        EvidenceSubmission
        .errored
        .where(created_at: from..to, supportable_type: 'AppealsApi::NoticeOfDisagreement')
        .order(created_at: :desc)
    end

    # Evidence submissions - SC
    def sc_evidence_submission_by_status_and_count
      group_evidence_submission_records(EvidenceSubmission, 'AppealsApi::SupplementalClaim')
    end

    def sc_faulty_evidence_submission
      @sc_faulty_evidence_submission ||=
        EvidenceSubmission
        .errored
        .where(created_at: from..to, supportable_type: 'AppealsApi::SupplementalClaim')
        .order(created_at: :desc)
    end

    def no_faulty_records?
      faulty_hlr.empty? && faulty_nod.empty? && faulty_sc.empty?
    end

    private

    def group_appeal_records(record_type)
      group_records(record_type, record_type.where(created_at: from..to))
    end

    def group_evidence_submission_records(record_type, supportable_type)
      group_records(record_type, record_type.where(created_at: from..to, supportable_type: supportable_type))
    end

    def group_records(record_type, record_collection)
      statuses = record_type::STATUSES.sort.index_with { |_| 0 }

      record_collection
        .group_by(&:status)
        .each { |status, record_list| statuses[status] = record_list.size }

      statuses
    end

    def total_statuses_count(record_type, statuses = ['complete'])
      record_type.where(status: statuses).count
    end

    def stuck_records(record_type, status_class, timeframe = 1.week.ago)
      record_type.where('updated_at < ?', timeframe.beginning_of_day)
                 .where(status: status_class::STATUSES - status_class::COMPLETE_STATUSES - FAULTY_STATUSES)
                 .order(created_at: :desc)
    end
  end
end
