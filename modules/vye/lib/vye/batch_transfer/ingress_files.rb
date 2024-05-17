# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      module_function

      BDN_FEED_FILENAME = 'WAVE.txt'
      TIMS_FEED_FILENAME = 'tims32towave.txt'

      def bdn_feed_filename = BDN_FEED_FILENAME
      def tims_feed_filename = TIMS_FEED_FILENAME

      def bdn_import(data)
        bdn_clone = BdnClone.create!
        source = :bdn_feed
        data.each_line.with_index do |line, index|
          locator = index + 1
          line.chomp!
          records = BdnLineExtraction.new(line:).attributes
          Vye::LoadData.new(source:, locator:, bdn_clone:, records:)
        end
      end

      def tims_import(data)
        source = :tims_feed
        data.each.with_index do |row, index|
          locator = index + 1
          records = TimsLineExtraction.new(row:).records
          Vye::LoadData.new(source:, locator:, records:)
        end
      end
    end
  end
end
