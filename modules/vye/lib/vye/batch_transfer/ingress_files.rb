# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      BDN_FEED_FILENAME = 'WAVE.txt'
      TIMS_FEED_FILENAME = 'tims32towave.txt'

      private_constant :BDN_FEED_FILENAME, :TIMS_FEED_FILENAME

      include Vye::CloudTransfer

      extend self

      private

      def bdn_feed_filename = BDN_FEED_FILENAME

      def tims_feed_filename = TIMS_FEED_FILENAME

      def bdn_import(path)
        counts = { success: 0, failure: 0 }
        bdn_clone = BdnClone.create!(transact_date: Time.zone.today)
        source = :bdn_feed
        path.each_line.with_index do |line, index|
          locator = index + 1
          line.chomp!
          records = BdnLineExtraction.new(line:).attributes
          ld = Vye::LoadData.new(source:, locator:, bdn_clone:, records:)
          if ld.valid?
            counts[:success] += 1
          else
            counts[:failure] += 1
          end
        end
        Rails.logger.info "BDN Import completed: success: #{counts[:success]}, failure: #{counts[:failure]}"
        bdn_clone.update!(is_active: false)
      end

      def tims_import(path)
        Vye::PendingDocument.delete_all
        counts = { success: 0, failure: 0 }
        data = CSV.open(path, 'r', headers: %i[ssn file_number doc_type queue_date rpo])
        source = :tims_feed
        data.each.with_index do |row, index|
          locator = index + 1
          records = TimsLineExtraction.new(row:).records
          ld = Vye::LoadData.new(source:, locator:, records:)
          if ld.valid?
            counts[:success] += 1
          else
            counts[:failure] += 1
          end
        end
        Rails.logger.info "TIMS Import completed: success: #{counts[:success]}, failure: #{counts[:failure]}"
      end

      public

      def clear_fixtures = clear_from(bucket: :internal, path: 'scanned')

      def bdn_load = download(bdn_feed_filename, &method(:bdn_import))

      def tims_load = download(tims_feed_filename, &method(:tims_import))
    end
  end
end
