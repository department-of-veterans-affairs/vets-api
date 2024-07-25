# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressBdn
      include Sidekiq::Job

      def perform
        Vye::BatchTransfer::IngressFiles.bdn_load
        IngressTims.perform_async
      end
    end
  end
end
