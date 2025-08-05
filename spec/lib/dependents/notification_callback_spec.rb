# frozen_string_literal: true

require 'dependents/monitor'
require 'dependents/notification_callback'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe Dependents::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', Dependents::NotificationCallback, Dependents::Monitor
end
