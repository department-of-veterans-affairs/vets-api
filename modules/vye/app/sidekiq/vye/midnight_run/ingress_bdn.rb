# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressBdn
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        Vye::BatchTransfer::IngressFiles.bdn_load
        IngressTims.perform_async
      end
    end
  end
end
