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
        Rails.logger.info('Vye::BatchTransfer::Chunk#build_chunks: starting')
        filename = feed_filename
        chunking = Vye::BatchTransfer::Chunking.new(filename:, block_size:)

        chunks = chunking.split
        chunks.each(&:upload)

        Rails.logger.info('Vye::BatchTransfer::Chunk#build_chunks: returning chunks')
        chunks
      end

      def initialize(offset:, block_size:, file: nil, filename: nil)
        Rails.logger.info(
          "Vye::BatchTransfer::Chunk#initialize: offset=#{offset}, block_size=#{block_size}, file=#{file}, " \
          "filename=#{filename}"
        )

        raise ArgumentError, "can't have both a file and filename" if file && filename
        raise ArgumentError, 'must have either a file or a filename' unless file || filename

        @offset = offset
        @block_size = block_size
        @file = file
        @filename = filename
        Rails.logger.info('Vye::BatchTransfer::Chunk#initialize: finished')
      end

      def prefix = 'chunks'

      def filename
        @filename || file.basename
      end

      # Upload is in Vye::CloudTransfer
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

      # Download is in Vye::CloudTransfer
      def load
        Rails.logger.info('Vye::BatchTransfer::Chunk#load: starting')

        download do |file|
          @file = file
          import
        end

        Rails.logger.info('Vye::BatchTransfer::Chunk#load: finished')
      end
    end
  end
end
