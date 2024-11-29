# frozen_string_literal: true

require 'common/models/base'
require 'post911_sob/dgib/entitlement'

module Post911SOB
  module DGIB
    class Response < Common::Base
      attribute :entitlement_transferred_out, Entitlement

      def initialize(status, response = nil)
        attributes = {
          entitlement_transferred_out: calculate_toe(response)
        }
        super(attributes)
        # TO-DO: Serialize status if necessary
      end

      private

      def calculate_toe(response)
        # TO-DO: Filter TOEs by 'Chapter33' benefit type
        # TO-DO: Calculate sum of entitlement amounts transferred out
        # TO-DO: Return zero value if no transfers
      end
    end
  end
end
