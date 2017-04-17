# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetDeploymentResponse < EMIS::Responses::Response
      def items
        locate('deployment').map do |el|
          build_item(el)
        end
      end

      private

      def build_item(el)
        OpenStruct.new(
          segment_identifier: locate_one('deploymentSegmentIdentifier', el).nodes[0],
          begin_date: Date.parse(locate_one('deploymentStartDate', el).nodes[0]),
          end_date: Date.parse(locate_one('deploymentEndDate', el).nodes[0]),
          project_code: locate_one('deploymentProjectCode', el).nodes[0],
          termination_reason: locate_one('deploymentTerminationReason', el).nodes[0],
          transaction_date: Date.parse(locate_one('deploymentTransactionDate', el).nodes[0]),
          locations: build_locations(el)
        )
      end

      def build_locations(el)
        locate('DeploymentLocation', el).map do |loc|
          OpenStruct.new(
            segment_identifier: locate_one('deploymentLocationSegmentIdentifier', loc).nodes[0],
            country: locate_one('deploymentCountry', loc).nodes[0],
            iso_alpha3_country: locate_one('deploymentISOAlpha3Country', loc).nodes[0],
            begin_date: Date.parse(locate_one('deploymentLocationBeginDate', loc).nodes[0]),
            end_date: Date.parse(locate_one('deploymentLocationEndDate', loc).nodes[0]),
            termination_reason_code: locate_one('deploymentLocationTerminationReasonCode', loc).nodes[0],
            transaction_date: Date.parse(locate_one('deploymentLocationTransactionDate', loc).nodes[0])
          )
        end
      end
    end
  end
end
