# frozen_string_literal: true

module Vye
  class SundownSweep
    class PurgesStaleVerifications
      include Sidekiq::Worker

      def perform; end
    end
  end
end
