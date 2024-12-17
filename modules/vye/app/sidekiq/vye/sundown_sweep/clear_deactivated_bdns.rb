# frozen_string_literal: true

module Vye
  class SundownSweep
    class ClearDeactivatedBdns
      include Sidekiq::Worker

      def perform
        logger.info('Beginning: delete deactivated bdns')
        Vye::CloudTransfer.delete_inactive_bdns
        logger.info('Finishing: delete deactivated bdns')
      end
    end
  end
end
