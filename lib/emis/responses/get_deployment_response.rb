# frozen_string_literal: true

require 'emis/models/deployment'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetDeploymentResponse < EMIS::Responses::Response
      def item_tag_name
        'deployment'
      end

      # rubocop:disable Metrics/MethodLength
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
            model_class: EMIS::Models::DeploymentLocation,
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

      def model_class
        EMIS::Models::Deployment
      end
    end
  end
end
