# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressBdn
      include Sidekiq::Job
      sidekiq_options retry: 8, unique_for: 12.hours

      def perform
        Vye::BatchTransfer::IngressFiles.bdn_load
        IngressTims.perform_async
      end
    end
  end
end
