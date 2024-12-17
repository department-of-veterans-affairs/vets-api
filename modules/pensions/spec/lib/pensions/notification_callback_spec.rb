# frozen_string_literal: true

require 'pensions/monitor'
require 'pensions/notification_callback'

require 'rails_helper'
require 'lib/va_notify/notification_callback/shared/saved_claim'

RSpec.describe Pensions::NotificationCallback do
    it_behaves_like 'a SavedClaim Notification Callback', Pensions::NotificationCallback, Pensions::Monitor
end
