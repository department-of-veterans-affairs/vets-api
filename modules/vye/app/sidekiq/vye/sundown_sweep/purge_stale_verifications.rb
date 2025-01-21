# frozen_string_literal: true

module Vye
  class SundownSweep
    class PurgeStaleVerifications
      include Sidekiq::Worker
      def perform
        Rails.logger.info('Vye::SundownSweep::PurgeStaleVerifications: starting purge of stale verifications')
        # The Specs stated: Every day delete anything that the created_on (timestamp) is older than 5 years.
        # Created_at has an index.
        Vye::Verification.where('created_at < ?', 5.years.ago).delete_all
        Rails.logger.info('Vye::SundownSweep::PurgeStaleVerifications: finished purge of stale verifications')
      end
    end
  end
end
