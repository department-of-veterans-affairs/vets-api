# frozen_string_literal: true

require 'increase_compensation/notification_callback'
require 'increase_compensation/monitor'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe IncreaseCompensation::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', IncreaseCompensation::NotificationCallback,
                  IncreaseCompensation::Monitor
end
