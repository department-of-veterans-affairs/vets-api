# frozen_string_literal: true

module Vye
  class SundownSweep
    include Sidekiq::Worker

    def perform
      ClearDeactivatedBdn.perform_async
      DeleteProcessedS3Files.perform_async
      PurgesStaleVerifications.perform_async
    end
  end
end
