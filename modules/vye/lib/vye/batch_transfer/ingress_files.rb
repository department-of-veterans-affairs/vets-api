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
        source = :bdn_feed
        data.each_line do |line|
          line.chomp!
          records = BdnLineExtraction.new(line:).attributes
          Vye::LoadData.new(source:, records:)
        end
      end

      def tims_import(data)
        source = :tims_feed
        data.each do |row|
          records = TimsLineExtraction.new(row:).records
          Vye::LoadData.new(source:, records:)
        end
      end
    end
  end
end
