# frozen_string_literal: true

module AppealsApi
  class RemovePii
    include SentryLogging

    APPEALS_TYPES = [
      HigherLevelReview,
      NoticeOfDisagreement
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
      # complete forms that contain pii over a week old

      @records_to_be_expunged ||=
        form_type.where.not(encrypted_form_data: nil)
                 .or(
                   form_type.where.not(
                     encrypted_auth_headers: nil
                   )
                 ).where(
                   status: form_type::COMPLETE_STATUSES
                 ).where(
                   'updated_at < ?', 1.week.ago
                 )
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
