# frozen_string_literal: true

module SignIn
  module Logingov
    class RiscEvent
      include ActiveModel::Validations

      EVENT_TYPES = %i[
        account_disabled
        account_enabled
        mfa_limit_account_locked
        account_purged
        identifier_changed
        identifier_recycled
        password_reset
        recovery_activated
        recovery_information_changed
        reproof_completed
      ].freeze

      attr_accessor :event_type, :email, :logingov_uuid, :reason, :event_occurred_at

      validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
      validate :email_or_uuid_present

      def initialize(event:)
        event_uri = event.keys.first
        subject = event.dig(event_uri, :subject)

        @event_type = normalize_event_type(event_uri)
        @email = subject[:email]
        @logingov_uuid = subject[:sub]
        @reason = event.dig(event_uri, :reason)
        @event_occurred_at = Time.zone.at(event.dig(event_uri, :event_occurred_at) || Time.current)
      end

      def to_h_masked
        {
          event_type:,
          email: email.present? ? '[FILTERED]' : nil,
          logingov_uuid:,
          reason:,
          event_occurred_at: event_occurred_at.iso8601
        }
      end

      private

      def normalize_event_type(event_uri)
        event_uri.to_s.split('/').last&.tr('-', '_')&.to_sym
      end

      def email_or_uuid_present
        errors.add(:base, 'email or logingov_uuid must be present') if email.blank? && logingov_uuid.blank?
      end
    end
  end
end
