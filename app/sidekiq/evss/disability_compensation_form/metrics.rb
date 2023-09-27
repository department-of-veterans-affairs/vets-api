# frozen_string_literal: true

require 'sidekiq/form526_job_status_tracker/job_tracker'

module EVSS
  module DisabilityCompensationForm
    # Helper class that fires off StatsD metrics
    #
    # @param prefix [String] Will prefix all metric names
    #
    class Metrics
      include Sidekiq::Form526JobStatusTracker::JobTracker
    end
  end
end
