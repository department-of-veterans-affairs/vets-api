# frozen_string_literal: true

module VYE; end
module VYE::BatchTransfer; end

module VYE::BatchTransfer::IngressFiles
  module_function

  BDN_FEED_FILENAME = 'WAVE.txt'
  TIMS_FEED_FILENAME = 'tims32towave.txt'

  def bdn_feed_filename = BDN_FEED_FILENAME
  def tims_feed_filename = TIMS_FEED_FILENAME
end
