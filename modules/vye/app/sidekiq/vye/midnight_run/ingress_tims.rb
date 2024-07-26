# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressTims
      include Sidekiq::Job
      sidekiq_options retry: 8, unique_for: 12.hours

      def perform
        Vye::BatchTransfer::IngressFiles.tims_load
      end
    end
  end
end
