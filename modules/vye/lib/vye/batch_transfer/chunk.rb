# frozen_string_literal: true

module Vye
  module BatchTransfer
    class Chunk
      BLOCK_SIZE = 25_000

      include Vye::CloudTransfer

      attr_reader :offset, :block_size, :file

      def self.block_size = BLOCK_SIZE

      def self.feed_filename
        raise NotImplementedError
      end

      def self.build_chunks
        filename = feed_filename
        chunking = Vye::BatchTransfer::Chunking.new(filename:, block_size:)

        chunks = chunking.split
        chunks.each(&:upload)

        chunks
      end

      def initialize(offset:, block_size:, file: nil, filename: nil)
        raise ArgumentError, "can't have both a file and filename" if file && filename
        raise ArgumentError, 'must have either a file or a filename' unless file || filename

        @offset = offset
        @block_size = block_size
        @file = file
        @filename = filename
      end

      def prefix = 'chunks'

      def filename
        @filename || file.basename
      end

      def upload
        raise ArgumentError, 'must have a file to upload' unless file

        super(file, prefix:)
      ensure
        file.delete
      end

      def download(&)
        raise ArgumentError, 'must have a filename to download' unless filename

        super(filename, prefix:, &)
      end

      def import
        raise NotImplementedError
      end

      def load
        download do |file|
          @file = file
          import
        end
      end
    end
  end
end
