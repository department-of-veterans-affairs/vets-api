# frozen_string_literal: true

require 'employment_questionnaires/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module EmploymentQuestionnaires
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see EmploymentQuestionnaires::Monitor
    def monitor
      @monitor ||= EmploymentQuestionnaires::Monitor.new
    end
  end
end
