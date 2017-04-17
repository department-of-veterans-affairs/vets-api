# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetVeteranStatusResponse < EMIS::Responses::Response
      def title_38_status_code
        locate_one('title38StatusCode').nodes.first
      end

      def post_911_deployment?
        locate_one('post911DeploymentIndicator').nodes.first == 'Y'
      end

      def post_911_combat?
        locate_one('post911CombatIndicator').nodes.first == 'Y'
      end

      def pre_911_deployment?
        locate_one('pre911DeploymentIndicator').nodes.first == 'Y'
      end
    end
  end
end
