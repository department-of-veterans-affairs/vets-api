# frozen_string_literal: true

module Vye
  class DawnDash
    class ActivateBdn
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        if Vye::CloudTransfer.holiday?
          logger.info('Vye::DawnDash::ActivateBdn: holiday detected, skipping')
          return
        end
        
        BdnClone.activate_injested!
        EgressUpdates.perform_async
      end
    end
  end
end
