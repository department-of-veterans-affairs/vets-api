# frozen_string_literal: true

require_relative '../helpers'

module Vye
  class SundownSweep
    class ClearDeactivatedBdns
      include Sidekiq::Worker

      def perform
        return if holiday?

        logger.info('Beginning: delete deactivated bdns')
        Vye::CloudTransfer.delete_inactive_bdns
        logger.info('Finishing: delete deactivated bdns')
      end
    end
  end
end
