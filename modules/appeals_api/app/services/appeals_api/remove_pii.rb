# frozen_string_literal: true

require 'datadog'

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
      Datadog::Tracing.trace("#{self.class.name} - #{form_type}") do
        validate_form_type!

        result = remove_pii!

        if result.blank? && records_to_be_expunged.present?
          ids = records_to_be_expunged.pluck(:id)
          msg = "Failed to remove expired #{form_type} PII from records"
          Rails.logger.error(msg, ids)
          AppealsApi::Slack::Messager.new({ msg:, ids: }).notify!
        end

        result
      end
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
      @records_to_be_expunged ||= form_type.with_expired_pii
    end
  end
end
