# frozen_string_literal: true

require 'emis/models/veteran_status'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS veteran status response
    class GetVeteranStatusResponse < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'veteranStatus'
      end

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'title38StatusCode' => {},
          'post911DeploymentIndicator' => {},
          'post911CombatIndicator' => {},
          'pre911DeploymentIndicator' => {}
        }
      end

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::VeteranStatus
      end
    end
  end
end
