# frozen_string_literal: true

module Vye
  class SundownSweep
    class PurgeStaleVerifications
      include Sidekiq::Worker
      def perform
        return if Vye::CloudTransfer.holiday?

        logger.info('Vye::SundownSweep::PurgeStaleVerifications: starting purge of stale verifications')
        Vye::CloudTransfer.purge_stale_verifications
        logger.info('Vye::SundownSweep::PurgeStaleVerifications: finished purge of stale verifications')
      end
    end
  end
end
