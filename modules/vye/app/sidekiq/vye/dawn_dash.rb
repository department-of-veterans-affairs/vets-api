# frozen_string_literal: true

module Vye
  class DawnDash
    include Sidekiq::Worker

    def perform
      return if Flipper.enabled?(:disable_bdn_processing)

      ActivateBdn.perform_async
    end
  end
end
