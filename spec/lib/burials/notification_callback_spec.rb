# frozen_string_literal: true

require 'burials/monitor'
require 'burials/notification_callback'

# relative to `spec` folder
require 'rails_helper'
require 'lib/va_notify/notification_callback/shared/saved_claim'

RSpec.describe Burials::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', Burials::NotificationCallback, Burials::Monitor
end
