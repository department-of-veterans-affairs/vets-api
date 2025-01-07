# frozen_string_literal: true

module Vye
  module BatchTransfer
    class BdnChunk < Vye::BatchTransfer::Chunk
      FEED_FILENAME = 'WAVE.txt'

      attr_reader :bdn_clone

      def self.feed_filename = FEED_FILENAME

      def initialize(bdn_clone_id:, offset:, block_size:, filename:)
        Rails.logger.info('Vye::BatchTransfer::BdnChunk#initialize: starting')

        @bdn_clone = Vye::BdnClone.find(bdn_clone_id)
        super(offset:, block_size:, filename:)

        Rails.logger.info('Vye::BatchTransfer::BdnChunk#initialize: finished')
      end

      def import
        clear_existing_records

        locator = offset
        counts = { success: 0, failure: 0 }

        file.each_line do |line|
          locator += 1

          line.chomp!
          records = Vye::BatchTransfer::IngressFiles::BdnLineExtraction.new(line:).attributes

          ld = Vye::LoadData.new(source:, locator:, bdn_clone:, records:)

          if ld.valid?
            counts[:success] += 1
          else
            counts[:failure] += 1
          end
        end

        Rails.logger.info "BDN Import completed: success: #{counts[:success]}, failure: #{counts[:failure]}"

        counts
      end

      private

      def source = :bdn_feed

      def clear_existing_records
        bdn_clone
          .user_infos
          .where('bdn_clone_line > ? AND bdn_clone_line <= ?', offset, offset + block_size)
          .delete_all
      end
    end
  end
end
