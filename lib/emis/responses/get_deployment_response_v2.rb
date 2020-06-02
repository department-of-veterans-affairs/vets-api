# frozen_string_literal: true

require 'emis/models/deployment_v2'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS get deployments response
    class GetDeploymentResponseV2 < EMIS::Responses::Response
      # (see EMIS::Responses::GetCombatPayResponse#item_tag_name)
      def item_tag_name
        'deployment'
      end

      # rubocop:disable Metrics/MethodLength

      # (see EMIS::Responses::GetCombatPayResponse#item_schema)
      def item_schema
        {
          'deploymentSegmentIdentifier' => { rename: 'segment_identifier' },
          'deploymentStartDate' => { rename: 'begin_date' },
          'deploymentEndDate' => { rename: 'end_date' },
          'deploymentProjectCode' => { rename: 'project_code' },
          'deploymentTerminationReason' => { rename: 'termination_reason' },
          'deploymentTransactionDate' => { rename: 'transaction_date' },
          'DeploymentLocation' => {
            rename: 'locations',
            model_class: EMIS::Models::DeploymentLocationV2,
            schema: {
              'deploymentLocationSegmentIdentifier' => { rename: 'segment_identifier' },
              'deploymentCountry' => { rename: 'country' },
              'deploymentISOAlpha3Country' => { rename: 'iso_alpha3_country' },
              'deploymentLocationBeginDate' => { rename: 'begin_date' },
              'deploymentLocationEndDate' => { rename: 'end_date' },
              'deploymentLocationTerminationReasonCode' => { rename: 'termination_reason_code' },
              'deploymentLocationTransactionDate' => { rename: 'transaction_date' }
            }
          }
        }
      end
      # rubocop:enable Metrics/MethodLength

      # (see EMIS::Responses::GetCombatPayResponse#model_class)
      def model_class
        EMIS::Models::DeploymentV2
      end
    end
  end
end
