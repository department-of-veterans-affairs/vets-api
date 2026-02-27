# frozen_string_literal: true

require 'education_benefits_claims/monitor'
require 'education_benefits_claims/notification_callback'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe EducationBenefitsClaims::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', EducationBenefitsClaims::NotificationCallback, EducationBenefitsClaims::Monitor
end
