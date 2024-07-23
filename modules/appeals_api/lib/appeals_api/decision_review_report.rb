# frozen_string_literal: true

module AppealsApi
  class DecisionReviewReport
    attr_reader :from, :to, :unidentified_mail_error_from

    FAULTY_STATUSES = %w[error].freeze

    # error "detail" for appeals who's identity is not recoginized in caseflow, nothing we nor they can do with these
    UNIDENTIFIED_MAIL_ERROR_DETAIL = 'Downstream status: Unidentified Mail: We could not associate part or all of ' \
                                     'this submission with a Veteran. Please verify the identifying information ' \
                                     'and resubmit.'

    # surpress reporting appeals that hit the caseflow Unidentified Mail error that are older than
    UNIDENTIFIED_MAIL_MAX_AGE = 1.month

    def initialize(from: nil, to: nil)
      @from = from
      @to = to
      # Unidentified Mail errors should only show for 1 month at the most,
      # use the user provided 'from' if it's less than 1 month ago
      time_1_month_ago = (Time.zone.now - UNIDENTIFIED_MAIL_MAX_AGE.seconds).to_time
      @unidentified_mail_error_from = [Time.zone.at(from.to_i), time_1_month_ago].max
    end

    # HLR
    def hlr_by_status_and_count
      group_appeal_records(HigherLevelReview)
    end

    def faulty_hlr
      @faulty_hlr ||= HigherLevelReview.where(created_at: from..to, status: FAULTY_STATUSES)
                                       .where('detail != ? OR detail IS NULL', UNIDENTIFIED_MAIL_ERROR_DETAIL)
                                       .or(HigherLevelReview.where(created_at: unidentified_mail_error_from..to,
                                                                   status: FAULTY_STATUSES,
                                                                   detail: UNIDENTIFIED_MAIL_ERROR_DETAIL))
                                       .order(created_at: :desc)
    end

    def total_hlr_successes
      # HLRv1s final success status is "success", while HLRv2/v0 is "complete", so we need to count on both
      @total_hlr_successes ||= lambda do
        sum = total_statuses_count(HigherLevelReview.v1, ['success'])
        sum += total_statuses_count(HigherLevelReview.v2_or_v0, ['complete'])
        sum
      end.call
    end

    # NOD
    def nod_by_status_and_count
      group_appeal_records(NoticeOfDisagreement)
    end

    def faulty_nod
      @faulty_nod ||= NoticeOfDisagreement.where(created_at: from..to, status: FAULTY_STATUSES)
                                          .where('detail != ? OR detail IS NULL', UNIDENTIFIED_MAIL_ERROR_DETAIL)
                                          .or(NoticeOfDisagreement.where(created_at: unidentified_mail_error_from..to,
                                                                         status: FAULTY_STATUSES,
                                                                         detail: UNIDENTIFIED_MAIL_ERROR_DETAIL))
                                          .order(created_at: :desc)
    end

    def total_nod_successes
      @total_nod_successes ||= total_statuses_count(NoticeOfDisagreement)
    end

    # SC
    def sc_by_status_and_count
      group_appeal_records(SupplementalClaim)
    end

    def faulty_sc
      @faulty_sc ||= SupplementalClaim.where(created_at: from..to, status: FAULTY_STATUSES)
                                      .where('detail != ? OR detail IS NULL', UNIDENTIFIED_MAIL_ERROR_DETAIL)
                                      .or(SupplementalClaim.where(created_at: unidentified_mail_error_from..to,
                                                                  status: FAULTY_STATUSES,
                                                                  detail: UNIDENTIFIED_MAIL_ERROR_DETAIL))
                                      .order(created_at: :desc)
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
      group_records(record_type, record_type.where(created_at: from..to, supportable_type:))
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
