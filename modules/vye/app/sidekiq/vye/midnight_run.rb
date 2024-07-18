# frozen_string_literal: true

module Vye
  class MidnightRun
    include Sidekiq::Worker

    def perform
      IngressBdn.perform_async
    end
  end
end
