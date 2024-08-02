# frozen_string_literal: true

module Vye
  module BatchTransfer
    class Chunking
      class NotReadyForUploading < StandardError; end

      include Vye::CloudTransfer

      def initialize(filename:, block_size:)
        @filename = filename
        @block_size = block_size
        @stem, @ext = filename.match(/(.*)[.]([^.]*)/).values_at(1, 2)
        @chunks = []
        @flags = %i[uploaded split].index_with { |_f| false }
      end

      def split
        return chunks if split?

        download(filename) do |path|
          path.each_line(&method(:puts))
        end

        split!
        chunks
      ensure
        close_current_handle
      end

      def upload
        return chunks if uploaded?
        raise NotReadyForUploading unless split?

        chunks.each(&:upload)

        uploaded!
        chunks
      end

      private

      attr_reader :filename, :block_size, :stem, :ext, :offset, :line_num, :chunks, :done

      def split! = @flags[:split] = true
      def split? = @flags[:split]

      def uploaded! = @flags[:uploaded] = true
      def uploaded? = @flags[:uploaded]

      def dirname
        @dirname ||= tmp_dir
      end

      def current_file
        return @current_file if @current_file.present?

        @offset = offset.blank? ? 0 : offset + line_num
        @line_num = 1

        filename = "#{stem}-#{offset}.#{ext}"
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
