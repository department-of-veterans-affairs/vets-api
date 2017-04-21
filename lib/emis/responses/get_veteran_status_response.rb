# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetVeteranStatusResponse < EMIS::Responses::Response
      def item_tag_name
        'veteranStatus'
      end

      def item_schema
        {
          'title38StatusCode' => {},
          'post911DeploymentIndicator' => {},
          'post911CombatIndicator' => {},
          'pre911DeploymentIndicator' => {}
        }
      end
    end
  end
end
