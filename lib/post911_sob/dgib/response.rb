# frozen_string_literal: true

require 'common/models/base'
require 'post911_sob/dgib/entitlement'
require 'post911_sob/dgib/client'

module Post911SOB
  module DGIB
    class Response < Common::Base
      attribute :entitlement_transferred_out, Entitlement

      def initialize(response = nil)
        transfers = response&.body.fetch('items', [])
        attributes = {
          entitlement_transferred_out: calculate_ch33_toe(transfers)
        }
        super(attributes)
        # TO-DO: Serialize status if necessary
      end

      private

      def calculate_ch33_toe(transfers)
        ch33_transfers = transfers.select { |t| t['benefitType'] == Post911SOB::DGIB::Client::BENEFIT_TYPE }
        ch33_transfers.inject(0) { |sum, t| sum + t['transferOut'] }
      end
    end
  end
end
