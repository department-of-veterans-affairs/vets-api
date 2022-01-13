# frozen_string_literal: true

require 'sidekiq/form526_job_status_tracker/job_tracker'
require 'sidekiq/form526_job_status_tracker/metrics'

module EVSS
  module DisabilityCompensationForm
    module JobStatus
      include Sidekiq::Form526JobStatusTracker::JobTracker
      # Module that is mixed in to {EVSS::DisabilityCompensationForm::Job} so that it's sub-classes
      # get automatic metrics and logging.
      #
    end
  end
end
