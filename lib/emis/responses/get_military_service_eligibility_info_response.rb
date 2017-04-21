# frozen_string_literal: true
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
            schema: {
              'title38StatusCode' => {},
              'post911DeploymentIndicator' => {},
              'post911CombatIndicator' => {},
              'pre911DeploymentIndicator' => {}
            }
          },
          'dentalIndicator' => {
            schema: {
              'dentalIndicatorSeperationDate' => { rename: 'separation_date', date: true },
              'dentalIndicator' => {}
            }
          },
          'militaryServiceEpisodes' => {
            schema: {
              'serviceEpisodeStartDate' => { rename: 'begin_date', date: true },
              'serviceEpisodeEndDate' => { rename: 'end_date', date: true },
              'branchOfServiceCode' => {},
              'dischargeCharacterOfServiceCode' => {},
              'honorableDischargeForVaPurposeCode' => {},
              'narrativeReasonForSeparationCode' => {},
              'deployments' => {
                schema: {
                  'deploymentSegmentIdentifier' => { rename: 'segment_identifier' },
                  'deploymentStartDate' => { rename: 'begin_date', date: true },
                  'deploymentEndDate' => { rename: 'end_date', date: true },
                  'deploymentProjectCode' => { rename: 'project_code' },
                  'DeploymentLocation' => {
                    rename: 'locations',
                    schema: {
                      'deploymentLocationSegmentIdentifier' => { rename: 'segment_identifier' },
                      'deploymentCountryCode' => { rename: 'country_code' },
                      'deploymentISOA3CountryCode' => { rename: 'iso_a3_country_code' }
                    }
                  }
                }
              },
              'combatPay' => {
                schema: {
                  'combatPaySegmentIdentifier' => { rename: 'segment_identifier' },
                  'combatPayBeginDate' => { rename: 'begin_date', date: true },
                  'combatPayEndDate' => { rename: 'end_date', date: true },
                  'combatPayTypeCode' => { rename: 'type_code' },
                  'combatZoneCountryCode' => {}
                }
              }
            }
          }
        }
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
