# frozen_string_literal: true

module Vye
  class SundownSweep
    class ClearDeactivatedBdns
      include Sidekiq::Worker

      def perform
<<<<<<< HEAD
=======
        return if Vye::CloudTransfer.holiday?

>>>>>>> ef3c0288176bba86adfb7abaf6e3a2c9bd88c1aa
        logger.info('Beginning: delete deactivated bdns')
        Vye::CloudTransfer.delete_inactive_bdns
        logger.info('Finishing: delete deactivated bdns')
      end
    end
  end
end
