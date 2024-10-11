# frozen_string_literal: true

module Vye
  class SundownSweep
    include Sidekiq::Worker

    def perform
      ClearDeactivatedBdns.perform_async
      DeleteProcessedS3Files.perform_async
      PurgeStaleVerifications.perform_async
    end
  end
end
