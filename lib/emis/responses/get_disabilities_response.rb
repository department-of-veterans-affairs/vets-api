# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetDisabilitiesResponse < EMIS::Responses::Response
      def disability_percent
        locate_one('disabilityPercent').nodes.first.to_f
      end

      def pay_amount
        locate_one('payAmount').nodes.first.to_f
      end
    end
  end
end
