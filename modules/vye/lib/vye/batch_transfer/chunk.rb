# frozen_string_literal: true

module Vye
  module BatchTransfer
    class Chunk
      include Vye::CloudTransfer

      def initialize(offset:, block_size:, file:)
        @offset = offset
        @block_size = block_size
        @file = file
      end

      def upload; end
    end
  end
end
