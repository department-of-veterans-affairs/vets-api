# frozen_string_literal: true

require 'employment_questionnaires/notification_callback'
require 'employment_questionnaires/monitor'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe EmploymentQuestionnaires::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', EmploymentQuestionnaires::NotificationCallback,
                  EmploymentQuestionnaires::Monitor
end
