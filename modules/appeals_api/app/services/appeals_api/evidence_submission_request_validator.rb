# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionRequestValidator
    EVIDENCE_SUBMISSION_DAYS_WINDOW = 91

    def initialize(nod_uuid, request_ssn)
      @nod_uuid = nod_uuid
      @request_ssn = request_ssn
    end

    def call
      return [:error, record_not_found_error] if notice_of_disagreement.blank?
      return [:error, invalid_review_option_error] unless evidence_accepted?
      return [:error, outside_legal_window_error] unless within_legal_window?
      return [:error, invalid_veteran_id_error] unless ssn_match?

      [:ok, {}]
    end

    private

    def notice_of_disagreement
      @notice_of_disagreement ||= AppealsApi::NoticeOfDisagreement.find_by(id: @nod_uuid)
    end

    def evidence_accepted?
      notice_of_disagreement.accepts_evidence?
    end

    def submitted_status
      @submitted_status ||= notice_of_disagreement
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
      return true unless notice_of_disagreement.auth_headers

      @request_ssn == notice_of_disagreement.auth_headers['X-VA-SSN']
    end

    def record_not_found_error
      { title: 'not_found', detail: I18n.t('appeals_api.errors.nod_not_found', id: @nod_uuid) }
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
  end
end
