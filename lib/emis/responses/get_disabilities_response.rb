# frozen_string_literal: true

require 'emis/models/disability'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS get disabilities response
    class GetDisabilitiesResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'disabilities'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'disabilityPercent' => {},
          'payAmount' => {}
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::Disability
      end
    end
  end
end
