# frozen_string_literal: true

require 'vre/vre_monitor'
require 'vre/notification_callback'

# relative to `spec` folder
require 'rails_helper'
require 'zero_silent_failures/monitor'
require 'veteran_facing_services/notification_email/saved_claim'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe VRE::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', VRE::NotificationCallback, VRE::VREMonitor
end
