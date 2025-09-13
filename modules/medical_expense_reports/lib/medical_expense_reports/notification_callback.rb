# frozen_string_literal: true

require 'medical_expense_reports/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module MedicalExpenseReports
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see MedicalExpenseReports::Monitor
    def monitor
      @monitor ||= MedicalExpenseReports::Monitor.new
    end
  end
end
