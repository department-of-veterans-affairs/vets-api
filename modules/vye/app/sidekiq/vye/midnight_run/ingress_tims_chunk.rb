# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressTimsChunk
      include Sidekiq::Job
      sidekiq_options retry: 3

      def perform(offset, block_size, filename)
        BatchTransfer::TimsChunk.new(offset:, block_size:, filename:).load
      end
    end
  end
end
