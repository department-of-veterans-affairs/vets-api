# frozen_string_literal: true

require 'emis/models/military_service_eligibility_info'
require 'emis/responses/response'

module EMIS
  module Responses
    class GetMilitaryServiceEligibilityInfoResponse < EMIS::Responses::Response
      def item_tag_name
        'militaryServiceEligibility'
      end

      # rubocop:disable Metrics/MethodLength
      def item_schema
        {
          'veteranStatus' => {
            rename: 'veteran_status',
            model_class: EMIS::Models::VeteranStatus,
            schema: {
              'title38StatusCode' => {},
              'post911DeploymentIndicator' => {},
              'post911CombatIndicator' => {},
              'pre911DeploymentIndicator' => {}
            }
          },
          'dentalIndicator' => {
            model_class: EMIS::Models::DentalIndicator,
            schema: {
              'dentalIndicatorSeperationDate' => { rename: 'separation_date' },
              'dentalIndicator' => {}
            }
          },
          'militaryServiceEpisodes' => {
            model_class: EMIS::Models::EligibilityMilitaryServiceEpisode,
            schema: {
              'serviceEpisodeStartDate' => { rename: 'begin_date' },
              'serviceEpisodeEndDate' => { rename: 'end_date' },
              'branchOfServiceCode' => {},
              'dischargeCharacterOfServiceCode' => {},
              'honorableDischargeForVaPurposeCode' => {},
              'narrativeReasonForSeparationCode' => {},
              'deployments' => {
                model_class: EMIS::Models::EligibilityDeployment,
                schema: {
                  'deploymentSegmentIdentifier' => { rename: 'segment_identifier' },
                  'deploymentStartDate' => { rename: 'begin_date' },
                  'deploymentEndDate' => { rename: 'end_date' },
                  'deploymentProjectCode' => { rename: 'project_code' },
                  'DeploymentLocation' => {
                    rename: 'locations',
                    model_class: EMIS::Models::EligibilityDeploymentLocation,
                    schema: {
                      'deploymentLocationSegmentIdentifier' => { rename: 'segment_identifier' },
                      'deploymentCountryCode' => { rename: 'country_code' },
                      'deploymentISOA3CountryCode' => { rename: 'iso_a3_country_code' }
                    }
                  }
                }
              },
              'combatPay' => {
                model_class: EMIS::Models::CombatPay,
                schema: {
                  'combatPaySegmentIdentifier' => { rename: 'segment_identifier' },
                  'combatPayBeginDate' => { rename: 'begin_date' },
                  'combatPayEndDate' => { rename: 'end_date' },
                  'combatPayTypeCode' => { rename: 'type_code' },
                  'combatZoneCountryCode' => {}
                }
              }
            }
          }
        }
      end
      # rubocop:enable Metrics/MethodLength

      def model_class
        EMIS::Models::MilitaryServiceEligibilityInfo
      end
    end
  end
end
