# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'military_information', type: :request do
  include JsonSchemaMatchers
  describe 'GET /mobile/v0/military-service-history' do
    context 'with a user who has a cached iam session' do
      before { iam_sign_in }

      let(:expected_body_multi) do
        {
          'data' => {
            'id' => '69ad43ea-6882-5673-8552-377624da64a5',
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Air Force',
                        'beginDate' => '2007-04-01',
                        'endDate' => '2016-06-01',
                        'formattedBeginDate' => 'April 01, 2007',
                        'formattedEndDate' => 'June 01, 2016'
                      },
                      {
                        'branchOfService' => 'United States Air Force',
                        'beginDate' => '2000-02-01',
                        'endDate' => '2004-06-14',
                        'formattedBeginDate' => 'February 01, 2000',
                        'formattedEndDate' => 'June 14, 2004'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_single) do
        {
          'data' => {
            'id' => '69ad43ea-6882-5673-8552-377624da64a5',
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Air Force',
                        'beginDate' => '2007-04-01',
                        'endDate' => '2016-06-01',
                        'formattedBeginDate' => 'April 01, 2007',
                        'formattedEndDate' => 'June 01, 2016'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_no_end_date) do
        {
          'data' => {
            'id' => '69ad43ea-6882-5673-8552-377624da64a5',
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '1990-11-02',
                        'endDate' => nil,
                        'formattedBeginDate' => 'November 02, 1990',
                        'formattedEndDate' => nil
                      },
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '1983-02-23',
                        'endDate' => '1988-10-04',
                        'formattedBeginDate' => 'February 23, 1983',
                        'formattedEndDate' => 'October 04, 1988'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_empty) do
        {
          'data' => {
            'id' => '69ad43ea-6882-5673-8552-377624da64a5',
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' => []
            }
          }
        }
      end

      context 'with multiple military service episodes' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
            get '/mobile/v0/military-service-history', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_multi)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'with one military service episode' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/valid') do
            get '/mobile/v0/military-service-history', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_single)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'military service episode with no end date' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/valid_no_end_date') do
            get '/mobile/v0/military-service-history', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_no_end_date)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'with an empty military service episode' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/empty') do
            get '/mobile/v0/military-service-history', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_empty)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      it 'returns unauthorized when requested without Bearer token' do
        get '/mobile/v0/military-service-history'
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns not found when requesting non-existent path' do
        get '/mobile/v0/military-service-history/doesnt-exist'
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
