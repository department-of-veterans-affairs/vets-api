# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'dependents_benefits/notification_callback'

require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe DependentsBenefits::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', DependentsBenefits::NotificationCallback, DependentsBenefits::Monitor
end
