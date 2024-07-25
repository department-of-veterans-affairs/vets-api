# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressTims
      include Sidekiq::Job

      def perform
        Vye::BatchTransfer::IngressFiles.tims_load
      end
    end
  end
end
