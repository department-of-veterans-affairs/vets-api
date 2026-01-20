# frozen_string_literal: true

require 'survivors_benefits/notification_callback'
require 'survivors_benefits/monitor'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe SurvivorsBenefits::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', SurvivorsBenefits::NotificationCallback,
                  SurvivorsBenefits::Monitor
end
