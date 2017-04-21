# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetDisabilitiesResponse < EMIS::Responses::Response
      def item_tag_name
        'disabilities'
      end

      def item_schema
        {
          'disabilityPercent' => { float: true },
          'payAmount' => { float: true }
        }
      end
    end
  end
end
