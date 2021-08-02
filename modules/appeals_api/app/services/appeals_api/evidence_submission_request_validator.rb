# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionRequestValidator
    EVIDENCE_SUBMISSION_DAYS_WINDOW = 91
    ACCEPTED_APPEAL_TYPES = %w[
      NoticeOfDisagreement
      SupplementalClaim
    ].freeze

    def initialize(appeal_uuid, request_ssn, appeal_type)
      @appeal_uuid = appeal_uuid
      @request_ssn = request_ssn
      @appeal_type = appeal_type

      raise_unacceptable_appeal_type?
    end

    def call
      return [:error, record_not_found_error] if appeal.blank?
      return [:error, invalid_review_option_error] unless evidence_accepted?
      return [:error, outside_legal_window_error] unless within_legal_window?
      return [:error, invalid_veteran_id_error] unless ssn_match?

      [:ok, {}]
    end

    private

    attr_accessor :appeal_uuid, :appeal_type

    def appeal
      @appeal ||= "AppealsApi::#{appeal_type}".constantize.find_by(id: appeal_uuid)
    end

    def evidence_accepted?
      appeal.accepts_evidence?
    end

    def submitted_status
      @submitted_status ||= appeal
                            .status_updates
                            .where(to: 'submitted').order(created_at: :desc).first
    end

    def within_legal_window?
      return true unless submitted_status

      submitted_status.status_update_time >=
        EVIDENCE_SUBMISSION_DAYS_WINDOW.days.ago.end_of_day
    end

    def ssn_match?
      # if PII expunged not validating for matching SSNs
      return true unless appeal.auth_headers

      @request_ssn == appeal.auth_headers['X-VA-SSN']
    end

    def record_not_found_error
      { title: 'not_found', detail: I18n.t('appeals_api.errors.not_found', id: appeal_uuid, type: appeal_type) }
    end

    def invalid_review_option_error
      { title: 'unprocessable_entity', detail: I18n.t('appeals_api.errors.no_evidence_submission_accepted') }
    end

    def invalid_veteran_id_error
      { title: 'unprocessable_entity', detail: I18n.t('appeals_api.errors.mismatched_ssns') }
    end

    def outside_legal_window_error
      { title: 'unprocessable_entity', detail: I18n.t('appeals_api.errors.outside_legal_window') }
    end

    def raise_unacceptable_appeal_type?
      raise UnacceptableAppealType unless @appeal_type.in?(ACCEPTED_APPEAL_TYPES)
    end
  end
end
