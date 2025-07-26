# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/monitor'
require 'accredited_representative_portal/notification_callback'

require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe AccreditedRepresentativePortal::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback',
                  AccreditedRepresentativePortal::NotificationCallback,
                  AccreditedRepresentativePortal::Monitor
end
