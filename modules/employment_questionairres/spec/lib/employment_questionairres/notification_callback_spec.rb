# frozen_string_literal: true

require 'employment_questionairres/notification_callback'
require 'employment_questionairres/monitor'

# relative to `spec` folder
require 'rails_helper'
require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe EmploymentQuestionairres::NotificationCallback do
  it_behaves_like 'a SavedClaim Notification Callback', EmploymentQuestionairres::NotificationCallback,
                  EmploymentQuestionairres::Monitor
end
