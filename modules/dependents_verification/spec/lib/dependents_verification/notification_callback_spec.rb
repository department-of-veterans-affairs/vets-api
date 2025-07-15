# frozen_string_literal: true

require 'dependents_verification/monitor'
require 'dependents_verification/notification_callback'

require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe DependentsVerification::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', DependentsVerification::NotificationCallback, DependentsVerification::Monitor
end
