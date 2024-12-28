# frozen_string_literal: true

module Vye
  module BatchTransfer
    class Chunking
      class NotReadyForUploading < StandardError; end

      include Vye::CloudTransfer

      def initialize(filename:, block_size:)
        Rails.logger.info("Vye::BatchTransfer::Chunking#initialize: filename=#{filename}, block_size=#{block_size}")

        @filename = filename
        @block_size = block_size
        @stem, @ext =
          if filename.include?('.')
            filename.rpartition('.').values_at(0, 2)
          else
            [filename, 'noext']
          end
        @chunks = []
        @flags = %i[split].index_with { |_f| false }
        Rails.logger.info('Vye::BatchTransfer::Chunking#initialize complete')
      end

      def split
        Rails.logger.info('Vye::BatchTransfer::Chunking#split starting')
        return chunks if split?

        download(filename) do |path|
          path.each_line(&method(:puts))
        end

        split!

        chunks
      rescue => e
        Rails.logger.error("Error splitting chunks: #{e.message}")
        nil
      ensure
        close_current_handle
        Rails.logger.info('Vye::BatchTransfer::Chunking#split complete')
      end

      private

      attr_reader :filename, :block_size, :stem, :ext, :offset, :line_num, :chunks, :done

      def split! = @flags[:split] = true
      def split? = @flags[:split]

      def dirname
        @dirname ||= tmp_dir
      end

      def current_file
        return @current_file if @current_file.present?

        @offset = offset.blank? ? 0 : offset + line_num
        @line_num = 1

        filename = "#{stem}_#{offset}.#{ext}"
        file = dirname / filename
        @current_file = file

        @chunks << Chunk.new(offset:, block_size:, file:)

        @current_file
      end

      def current_handle
        return @current_handle if @current_handle.present?

        @current_handle = current_file.open('w')
      end

      def close_current_handle
        @current_handle.close unless @current_handle.blank? || @current_handle.closed?
      end

      def complete_current_file!
        @current_handle.close
        @current_handle = nil
        @current_file = nil
      end

      def puts(line)
        current_handle.puts line

        if line_num == block_size
          complete_current_file!
        else
          @line_num += 1
        end
      end
    end
  end
end
