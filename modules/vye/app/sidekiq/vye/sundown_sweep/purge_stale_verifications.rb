# frozen_string_literal: true

module Vye
  class SundownSweep
    class PurgeStaleVerifications
      include Sidekiq::Worker

      def perform; end
    end
  end
end
