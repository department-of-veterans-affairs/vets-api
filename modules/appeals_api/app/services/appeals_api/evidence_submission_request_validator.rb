# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionRequestValidator
    ACCEPTED_APPEAL_TYPES = %w[
      NoticeOfDisagreement
      SupplementalClaim
    ].freeze

    def initialize(appeal_uuid, veteran_identifier, appeal_type)
      @appeal_uuid = appeal_uuid
      @veteran_identifier = veteran_identifier
      @appeal_type = appeal_type

      raise_unacceptable_appeal_type?
    end

    def call
      return [:error, record_not_found_error] if appeal.blank?
      return [:error, invalid_review_option_error] unless evidence_accepted?
      return [:error, submission_window_error] unless within_submission_window?
      return [:error, invalid_veteran_ssn_error || invalid_file_number_error] unless veteran_identifier_match?

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

    def within_submission_window?
      return true unless submitted_status

      submitted_status.status_update_time >=
        appeal.evidence_submission_days_window.days.ago.end_of_day
    end

    def veteran_identifier_match?
      appeal_identifier = appeal.auth_headers&.dig('X-VA-SSN') ||
                          appeal.auth_headers&.dig('X-VA-File-Number') ||
                          appeal.form_data&.dig('data', 'attributes', 'veteran', 'ssn') ||
                          appeal.form_data&.dig('data', 'attributes', 'veteran', 'fileNumber')

      # if PII expunged not validating for matching SSNs or File-Numbers
      appeal_identifier.blank? || appeal_identifier == @veteran_identifier
    end

    def record_not_found_error
      {
        title: 'not_found',
        detail: I18n.t('appeals_api.errors.not_found', id: appeal_uuid, type: appeal_type),
        code: '404',
        status: '404'
      }
    end

    def invalid_review_option_error
      {
        title: 'unprocessable_entity',
        detail: I18n.t('appeals_api.errors.no_evidence_submission_accepted'),
        code: 'InvalidReviewOption',
        status: '422'
      }
    end

    def invalid_veteran_ssn_error
      return unless appeal.veteran&.ssn

      {
        title: 'unprocessable_entity',
        detail: I18n.t("appeals_api.errors.mismatched_ssns#{identifier_in_headers? ? '' : '_in_body'}"),
        code: 'DecisionReviewMismatchedSSN',
        status: '422'
      }
    end

    def invalid_file_number_error
      return unless appeal.veteran&.file_number

      {
        title: 'unprocessable_entity',
        detail: I18n.t('appeals_api.errors.mismatched_file_numbers'),
        code: 'DecisionReviewMismatchedFileNumber',
        status: '422'
      }
    end

    def identifier_in_headers?
      # v0 APIs gather PII in the body, while decision reviews v2 uses headers.
      # Determine where the identifier is on this appeal instance:
      appeal.auth_headers&.dig('X-VA-SSN').present? || appeal.auth_headers&.dig('X-VA-File-Number').present?
    end

    def raise_unacceptable_appeal_type?
      raise UnacceptableAppealType unless @appeal_type.in?(ACCEPTED_APPEAL_TYPES)
    end

    def submission_window_error
      appeal.outside_submission_window_error
    end
  end
end
