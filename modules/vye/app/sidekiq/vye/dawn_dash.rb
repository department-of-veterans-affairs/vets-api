# frozen_string_literal: true

module Vye
  class DawnDash
    include Sidekiq::Worker

    def perform
      ActivateBdn.perform_async
    end
  end
end
