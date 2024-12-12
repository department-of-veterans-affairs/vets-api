# frozen_string_literal: true

require 'pensions/notification_callback'
require 'va_notify/notification_email/saved_claim'

module Pensions
  class NotificationEmail < ::VANotify::NotificationEmail::SavedClaim
    # @see VANotify::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id)
      super(saved_claim_id, service_name: 'pensions')
    end

    private

    def claim_class
      Pensions::SavedClaim
    end

    # @see VANotify::NotificationEmail::SavedClaim#personalization
    def personalization
      default = super

      # confirmation, error
      pensions = { 'first_name' => claim.first_name&.titleize }

      default.merge(pensions)
    end

    # @see VANotify::NotificationEmail::SavedClaim#callback_class
    def callback_klass
      "#{Pensions::NotificationCallback}"
    end
  end
end
