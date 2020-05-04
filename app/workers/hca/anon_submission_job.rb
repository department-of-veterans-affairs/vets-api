# frozen_string_literal: true

module HCA
  class AnonSubmissionJob < BaseSubmissionJob
    sidekiq_options retry: false

    def perform(*args)
      super
    rescue
      @health_care_application.update!(state: 'failed')
      raise
    end
  end
end
