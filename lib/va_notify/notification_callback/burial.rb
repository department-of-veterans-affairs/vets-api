# frozen_string_literal: true

require 'va_notify/notification_callback/saved_claim'

module Burials
  class NotificationCallback < ::VANotify::NotificationCallback::SavedClaim

    def call
      puts 'TEST'
      puts klass
    end

  end
end
