# frozen_string_literal: true

require 'sidekiq'

module CheckIn
  class TravelClaimSubmissionWorker
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker
    sidekiq_options retry: false

    def perform(uuid, appointment_date); end
  end
end
