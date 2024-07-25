# frozen_string_literal: true

module Vye
  class DawnDash
    class ActivateBdn
      include Sidekiq::Job

      def perform
        BdnClone.activate_injested!
        EgressUpdates.perform_async
      end
    end
  end
end
