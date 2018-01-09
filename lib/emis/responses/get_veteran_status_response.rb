# frozen_string_literal: true

require 'emis/models/veteran_status'
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

      def model_class
        EMIS::Models::VeteranStatus
      end
    end
  end
end
