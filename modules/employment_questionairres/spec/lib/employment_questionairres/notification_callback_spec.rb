# frozen_string_literal: true

require 'medical_expense_reports/notification_callback'
require 'medical_expense_reports/monitor'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe EmploymentQuestionairres::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', EmploymentQuestionairres::NotificationCallback,
                  EmploymentQuestionairres::Monitor
end
