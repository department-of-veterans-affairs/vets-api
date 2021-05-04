# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionRequestValidator

    EVIDENCE_SUBMISSION_DAYS_WINDOW = 91

    def initialize(nod_id, request_ssn)
      @nod_id = nod_id
      @request_ssn = request_ssn
    end

    def call
      return [:error, record_not_found_error] unless notice_of_disagreement.present?
      return [:error, invalid_review_option_error] unless evidence_accepted?
      return [:error, outside_legal_window_error] unless within_legal_window?
      return [:error, invalid_veteran_id_error] unless ssn_match?

      [:ok, {}]
    end

    private

    attr_accessor :notice_of_disagreement

    def notice_of_disagreement
      @notice_of_disagreement ||= AppealsApi::NoticeOfDisagreement.find_by(id: @nod_id)
    end

    def evidence_accepted?
      notice_of_disagreement.accepts_evidence?
    end

    def within_legal_window?
      notice_of_disagreement.
        status_updates.
        where(
          "appeals_api_status_updates.status_update_time >= ? AND
          appeals_api_status_updates.to = 'submitted'",
          EVIDENCE_SUBMISSION_DAYS_WINDOW.days.ago
        ).any?
    end

    def ssn_match?
      # if PII expunged not validating for matching SSNs
      return true unless notice_of_disagreement.auth_headers

      @request_ssn == notice_of_disagreement.auth_headers['X-VA-SSN']
    end

    def record_not_found_error
      { title: 'not_found', detail: I18n.t('appeals_api.errors.nod_not_found', id: @nod_id) }
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
