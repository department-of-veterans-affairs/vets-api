# frozen_string_literal: true

require 'va_notify/notification_email/saved_claim'

module Pensions
  class NotificationEmail < ::VANotify::NotificationEmail::SavedClaim
    # @see VANotify::NotificationEmail::SavedClaim
    # pass thru to super class, no additional processing needed
    def initialize(saved_claim)
      super(saved_claim, service_name: 'pensions')
    end
  end
end
