# frozen_string_literal: true

module Vye
  class SundownSweep
    class PurgeStaleVerifications
      include Sidekiq::Worker
      def perform
        Rails.logger.info('Vye::SundownSweep::PurgeStaleVerifications: starting purge of stale verifications')
        Vye::CloudTransfer.purge_stale_verifications
        Rails.logger.info('Vye::SundownSweep::PurgeStaleVerifications: finished purge of stale verifications')
      end
    end
  end
end
