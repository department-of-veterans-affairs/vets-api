# frozen_string_literal: true

require 'income_and_assets/notification_callback'
require 'income_and_assets/submissions/monitor'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe IncomeAndAssets::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', IncomeAndAssets::NotificationCallback,
                  IncomeAndAssets::Submissions::Monitor
end
