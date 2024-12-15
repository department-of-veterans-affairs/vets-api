# frozen_string_literal: true

module Vye
  class SundownSweep
    include Sidekiq::Worker

    def perform
      logger.info('Vye::SundownSweep starting')
      ClearDeactivatedBdns.perform_async
      DeleteProcessedS3Files.perform_async
      logger.info('Vye::SundownSweep finished')
    end
  end
end
