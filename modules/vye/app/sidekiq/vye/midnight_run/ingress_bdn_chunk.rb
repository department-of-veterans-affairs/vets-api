# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressBdnChunk
      include Sidekiq::Job
      sidekiq_options retry: 3

      # The load method is in Vye::BatchTransfer::Chunk which BdnChunk inherits
      def perform(bdn_clone_id, offset, block_size, filename)
        BatchTransfer::BdnChunk.new(bdn_clone_id:, offset:, block_size:, filename:).load
      end
    end
  end
end
