# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe 'military_information', type: :request do
  include SchemaMatchers
  describe 'GET /mobile/v0/military-service-history' do
    context 'with a user who has a cached iam session' do
      before { iam_sign_in }
      let(:inflection_header) { {'X-Key-Inflection' => 'camel'} }
      let(:expected_body_multi) do
        {
            'data' => {
                'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
                'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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

      context 'with multiple military service episodes' do
        it 'matches the service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
            get '/mobile/v0/military-service-history', headers: {'Authorization' => "Bearer #{access_token}"}
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_multi)
            expect(response).to match_response_schema('mobile_service_history_response')
          end
        end
      end

      context 'with one military service episode' do
        it 'matches the service history schema' do
          VCR.use_cassette('emis/get_military_service_episodes/valid') do
            get '/mobile/v0/military-service-history', headers: {'Authorization' => "Bearer #{access_token}"}
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_single)
            expect(response).to match_response_schema('mobile_service_history_response')
          end
        end
      end
    end
  end
end
