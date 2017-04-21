# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetDeploymentResponse < EMIS::Responses::Response
      def item_tag_name
        'deployment'
      end

      def item_schema
        {
          'deploymentSegmentIdentifier' => { rename: 'segment_identifier' },
          'deploymentStartDate' => { date: true, rename: 'begin_date' },
          'deploymentEndDate' => { date: true, rename: 'end_date' },
          'deploymentProjectCode' => { rename: 'project_code' },
          'deploymentTerminationReason' => { rename: 'termination_reason' },
          'deploymentTransactionDate' => { date: true, rename: 'transaction_date' },
          'DeploymentLocation' => {
            rename: 'locations',
            schema: {
              'deploymentLocationSegmentIdentifier' => { rename: 'segment_identifier' },
              'deploymentCountry' => { rename: 'country' },
              'deploymentISOAlpha3Country' => { rename: 'iso_alpha3_country' },
              'deploymentLocationBeginDate' => { date: true, rename: 'begin_date' },
              'deploymentLocationEndDate' => { date: true, rename: 'end_date' },
              'deploymentLocationTerminationReasonCode' => { rename: 'termination_reason_code' },
              'deploymentLocationTransactionDate' => { date: true, rename: 'transaction_date' }
            }
          }
        }
      end
    end
  end
end
