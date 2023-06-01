# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'military_information', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v0/military-service-history' do
    context 'with a user who has a cached iam session' do
      before { iam_sign_in }

      let(:expected_body_multi) do
        {
          'data' => {
            'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2002-02-02',
                        'endDate' => '2008-12-01',
                        'formattedBeginDate' => 'February 02, 2002',
                        'formattedEndDate' => 'December 01, 2008'
                      },
                      {
                        'branchOfService' => 'United States Navy',
                        'beginDate' => '2009-03-01',
                        'endDate' => '2012-12-31',
                        'formattedBeginDate' => 'March 01, 2009',
                        'formattedEndDate' => 'December 31, 2012'
                      },
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2012-03-02',
                        'endDate' => '2018-10-31',
                        'formattedBeginDate' => 'March 02, 2012',
                        'formattedEndDate' => 'October 31, 2018'
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
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2002-02-02',
                        'endDate' => '2008-12-01',
                        'formattedBeginDate' => 'February 02, 2002',
                        'formattedEndDate' => 'December 01, 2008'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_no_end_date) do
        {
          'data' => {
            'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2002-02-02',
                        'endDate' => nil,
                        'formattedBeginDate' => 'February 02, 2002',
                        'formattedEndDate' => nil
                      },
                      {
                        'branchOfService' => 'United States Navy',
                        'beginDate' => '2009-03-01',
                        'endDate' => '2012-12-31',
                        'formattedBeginDate' => 'March 01, 2009',
                        'formattedEndDate' => 'December 31, 2012'
                      },
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2012-03-02',
                        'endDate' => '2018-10-31',
                        'formattedBeginDate' => 'March 02, 2012',
                        'formattedEndDate' => 'October 31, 2018'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_empty) do
        {
          'data' => {
            'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' => []
            }
          }
        }
      end

      context 'with multiple military service episodes' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_histories_200') do
            get '/mobile/v0/military-service-history', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_multi)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'with one military service episode' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_history_200') do
            get '/mobile/v0/military-service-history', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_single)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'military service episode with no end date' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_histories_200_no_end_date') do
            get '/mobile/v0/military-service-history', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_no_end_date)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'with an empty military service episode' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_history_200_empty') do
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

    context 'with a user not authorized' do
      it 'returns a forbidden response' do
        user = FactoryBot.build(:iam_user, :no_edipi_id)
        iam_sign_in(user)
        get '/mobile/v0/military-service-history', headers: iam_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
