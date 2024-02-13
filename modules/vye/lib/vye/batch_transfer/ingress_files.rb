# frozen_string_literal: true

module VYE
  module BatchTransfer
    module IngressFiles
      module_function

      BDN_FEED_FILENAME = 'WAVE.txt'
      TIMS_FEED_FILENAME = 'tims32towave.txt'

      def bdn_feed_filename = BDN_FEED_FILENAME
      def tims_feed_filename = TIMS_FEED_FILENAME
    end
  end
end
