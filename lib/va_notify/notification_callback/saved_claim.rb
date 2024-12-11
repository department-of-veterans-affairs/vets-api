# frozen_string_literal: true

require 'va_notify/notification_callback'

module VANotify
  module NotificationCallback
    class SavedClaim < ::VANotify::NotificationCallback::Default

    def call
      puts 'TEST'
      puts klass
    end

  end
end
