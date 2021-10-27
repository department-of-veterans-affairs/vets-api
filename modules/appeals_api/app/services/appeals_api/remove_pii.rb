# frozen_string_literal: true

module AppealsApi
  class RemovePii
    include SentryLogging

    APPEALS_TYPES = [
      HigherLevelReview,
      NoticeOfDisagreement,
      SupplementalClaim
    ].freeze

    def initialize(form_type:)
      @form_type = form_type
    end

    def run!
      validate_form_type!

      result = remove_pii!

      log_failure_to_sentry if records_were_not_cleared(result)

      result
    end

    private

    attr_accessor :form_type

    def remove_pii!
      records_to_be_expunged.update(form_data: nil, auth_headers: nil)
    end

    def validate_form_type!
      raise ArgumentError, 'Invalid Form Type' unless valid_form_type?
    end

    def valid_form_type?
      form_type.in?(APPEALS_TYPES)
    end

    def records_to_be_expunged
      @records_to_be_expunged ||=
        form_type.where.not(form_data_ciphertext: nil)
                 .or(
                   form_type.where.not(
                     auth_headers_ciphertext: nil
                   )
                 ).pii_expunge_policy
    end

    def records_were_not_cleared(result)
      result.blank? && records_to_be_expunged.present?
    end

    def log_failure_to_sentry
      log_message_to_sentry(
        "Failed to expunge PII from #{form_type} (modules/appeals_api)",
        :error,
        ids: records_to_be_expunged.pluck(:id)
      )
    end
  end
end
