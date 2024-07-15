# frozen_string_literal: true

module Vye
  class SundownSweep
    class DeleteProcessedS3Files
      include Sidekiq::Worker

      def perform; end
    end
  end
end
