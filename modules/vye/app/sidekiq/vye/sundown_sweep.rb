# frozen_string_literal: true

module Vye
  class SundownSweep
    include Sidekiq::Worker

    def perform
      Rails.logger.info('Vye::SundownSweep starting')
      ClearDeactivatedBdns.perform_async
      DeleteProcessedS3Files.perform_async
      PurgeStaleVerifications.perform_async
      Rails.logger.info('Vye::SundownSweep finished')
    end
  end
end
