# frozen_string_literal: true

module Vye
  module BatchTransfer
    class TimsChunk < Vye::BatchTransfer::Chunk
      FEED_FILENAME = 'tims32towave.txt'

      def self.feed_filename = FEED_FILENAME

      def initialize(offset:, block_size:, filename:)
        super(offset:, block_size:, filename:)
      end

      def data = CSV.open(file, 'r', headers: %i[ssn file_number doc_type queue_date rpo])

      def import
        locator = offset
        counts = { success: 0, failure: 0 }

        data.each do |row|
          locator += 1

          records = Vye::BatchTransfer::IngressFiles::TimsLineExtraction.new(row:).records

          ld = Vye::LoadData.new(source:, locator:, records:)

          if ld.valid?
            counts[:success] += 1
          else
            counts[:failure] += 1
          end
        end

        Rails.logger.info "TIMS Import completed: success: #{counts[:success]}, failure: #{counts[:failure]}"

        counts
      end

      private

      def source = :tims_feed
    end
  end
end
