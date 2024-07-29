# frozen_string_literal: true

module Vye
  class DawnDash
    class ActivateBdn
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        BdnClone.activate_injested!
        EgressUpdates.perform_async
      end
    end
  end
end
