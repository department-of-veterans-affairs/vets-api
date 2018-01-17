# frozen_string_literal: true

require 'emis/models/disability'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetDisabilitiesResponse < EMIS::Responses::Response
      def item_tag_name
        'disabilities'
      end

      def item_schema
        {
          'disabilityPercent' => {},
          'payAmount' => {}
        }
      end

      def model_class
        EMIS::Models::Disability
      end
    end
  end
end
