# frozen_string_literal: true

require 'employment_questionairres/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module EmploymentQuestionairres
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see EmploymentQuestionairres::Monitor
    def monitor
      @monitor ||= EmploymentQuestionairres::Monitor.new
    end
  end
end
