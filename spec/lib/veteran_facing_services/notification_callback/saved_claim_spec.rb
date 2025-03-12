# frozen_string_literal: true

require 'veteran_facing_services/notification_callback/saved_claim'

require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe VeteranFacingServices::NotificationCallback::SavedClaim do
  it_behaves_like 'a SavedClaim Notification Callback', VeteranFacingServices::NotificationCallback::SavedClaim,
                  ZeroSilentFailures::Monitor
end
