# frozen_string_literal: true

module HCA
  class AnonSubmissionJob < BaseSubmissionJob
    sidekiq_options retry: false

    # TODO spec
    sidekiq_retries_exhausted do |msg, _e|
      health_care_application = HealthCareApplication.find(msg['args'][2])
      health_care_application.update_attributes!(
        state: 'failed'
      )
    end
  end
end
