# frozen_string_literal: true

module Vye
  class DawnDash
    class ActivateBdn
      include Sidekiq::Job
      sidekiq_options retry: 8, unique_for: 12.hours

      def perform
        BdnClone.activate_injested!
        EgressUpdates.perform_async
      end
    end
  end
end
