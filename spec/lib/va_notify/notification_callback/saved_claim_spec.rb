# frozen_string_literal: true

require 'va_notify/notification_callback/saved_claim'

require 'rails_helper'
require 'lib/va_notify/notification_callback/shared/saved_claim'

RSpec.describe VANotify::NotificationCallback::SavedClaim do
  it_behaves_like 'a SavedClaim Notification Callback', VANotify::NotificationCallback::SavedClaim,
                  ZeroSilentFailures::Monitor
end
