# frozen_string_literal: true

module Vye
  class DawnDash
    class ActivateBdn
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        Rails.logger.info 'Vye::DawnDash::ActivateBdn starting'
        BdnClone.activate_injested!
        Rails.logger.info 'Vye::DawnDash::ActivateBdn EgressUpdates starting (async)'
        EgressUpdates.perform_async
        Rails.logger.info 'Vye::DawnDash::ActivateBdn finished'
      end
    end
  end
end
