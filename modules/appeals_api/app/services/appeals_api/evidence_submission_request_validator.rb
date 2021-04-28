# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionRequestValidator
    def initialize(nod_id, request_ssn)
      @nod_id = nod_id
      @request_ssn = request_ssn
    end

    def call
      return [:error, record_not_found_error] unless notice_of_disagreement_exists?
      return [:error, invalid_review_option_error] unless @notice_of_disagreement.accepts_evidence?
      return [:error, invalid_veteran_id_error] unless ssn_match?

      [:ok, {}]
    end

    def notice_of_disagreement_exists?
      @notice_of_disagreement ||= AppealsApi::NoticeOfDisagreement.find_by(id: @nod_id)
    end

    private

    def record_not_found_error
      { title: 'not_found', detail: I18n.t('appeals_api.errors.nod_not_found', id: @nod_id) }
    end

    def invalid_review_option_error
      { title: 'unprocessable_entity', detail: I18n.t('appeals_api.errors.no_evidence_submission_accepted') }
    end

    def invalid_veteran_id_error
      { title: 'unprocessable_entity', detail: I18n.t('appeals_api.errors.mismatched_ssns') }
    end

    def ssn_match?
      return unless @notice_of_disagreement.auth_headers

      @request_ssn == @notice_of_disagreement.auth_headers['X-VA-SSN']
    end
  end
end
