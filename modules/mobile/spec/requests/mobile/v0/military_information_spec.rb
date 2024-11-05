# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::MilitaryInformation', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v0/military-service-history' do
    let!(:user) { sis_user(edipi: '1005079124') }

    context 'with a user who has a cached session' do
      let(:expected_body_multi) do
        {
          'data' => {
            'id' => user.uuid,
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2002-02-02',
                        'endDate' => '2008-12-01',
                        'formattedBeginDate' => 'February 02, 2002',
                        'formattedEndDate' => 'December 01, 2008',
                        'characterOfDischarge' => 'Dishonorable',
                        'honorableServiceIndicator' => 'N'
                      },
                      {
                        'branchOfService' => 'United States Navy',
                        'beginDate' => '2009-03-01',
                        'endDate' => '2012-12-31',
                        'formattedBeginDate' => 'March 01, 2009',
                        'formattedEndDate' => 'December 31, 2012',
                        'characterOfDischarge' => 'Unknown',
                        'honorableServiceIndicator' => 'Z'
                      },
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2012-03-02',
                        'endDate' => '2018-10-31',
                        'formattedBeginDate' => 'March 02, 2012',
                        'formattedEndDate' => 'October 31, 2018',
                        'characterOfDischarge' => 'Honorable',
                        'honorableServiceIndicator' => 'Y'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_single) do
        {
          'data' => {
            'id' => user.uuid,
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2002-02-02',
                        'endDate' => '2008-12-01',
                        'formattedBeginDate' => 'February 02, 2002',
                        'formattedEndDate' => 'December 01, 2008',
                        'characterOfDischarge' => 'Under honorable conditions (general)',
                        'honorableServiceIndicator' => 'Y'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_no_end_date) do
        {
          'data' => {
            'id' => user.uuid,
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' =>
                    [
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2002-02-02',
                        'endDate' => nil,
                        'formattedBeginDate' => 'February 02, 2002',
                        'formattedEndDate' => nil,
                        'characterOfDischarge' => 'DoD provided a value not in the reference table',
                        'honorableServiceIndicator' => 'Z'
                      },
                      {
                        'branchOfService' => 'United States Navy',
                        'beginDate' => '2009-03-01',
                        'endDate' => '2012-12-31',
                        'formattedBeginDate' => 'March 01, 2009',
                        'formattedEndDate' => 'December 31, 2012',
                        'characterOfDischarge' => 'Bad conduct',
                        'honorableServiceIndicator' => 'N'
                      },
                      {
                        'branchOfService' => 'United States Army',
                        'beginDate' => '2012-03-02',
                        'endDate' => '2018-10-31',
                        'formattedBeginDate' => 'March 02, 2012',
                        'formattedEndDate' => 'October 31, 2018',
                        'characterOfDischarge' => 'Honorable (Assumed) - GRAS periods only',
                        'honorableServiceIndicator' => 'Y'
                      }
                    ]
            }
          }
        }
      end

      let(:expected_body_empty) do
        {
          'data' => {
            'id' => user.uuid,
            'type' => 'militaryInformation',
            'attributes' => {
              'serviceHistory' => []
            }
          }
        }
      end

      let(:expected_no_discharge) do
        { 'data' =>
          { 'id' => user.uuid,
            'type' => 'militaryInformation',
            'attributes' =>
            { 'serviceHistory' =>
              [{ 'branchOfService' => 'United States Army',
                 'beginDate' => '2002-02-02',
                 'endDate' => '2008-12-01',
                 'formattedBeginDate' => 'February 02, 2002',
                 'formattedEndDate' => 'December 01, 2008',
                 'characterOfDischarge' => nil,
                 'honorableServiceIndicator' => nil },
               { 'branchOfService' => 'United States Army',
                 'beginDate' => '2012-03-02',
                 'endDate' => '2018-10-31',
                 'formattedBeginDate' => 'March 02, 2012',
                 'formattedEndDate' => 'October 31, 2018',
                 'characterOfDischarge' => nil,
                 'honorableServiceIndicator' => nil }] } } }
      end

      let(:expected_unknown_discharge) do
        { 'data' =>
          { 'id' => user.uuid,
            'type' => 'militaryInformation',
            'attributes' =>
            { 'serviceHistory' =>
              [{ 'branchOfService' => 'United States Army',
                 'beginDate' => '2012-03-02',
                 'endDate' => '2018-10-31',
                 'formattedBeginDate' => 'March 02, 2012',
                 'formattedEndDate' => 'October 31, 2018',
                 'characterOfDischarge' => nil,
                 'honorableServiceIndicator' => nil }] } } }
      end

      context 'when user does not have access' do
        let!(:user) { sis_user(edipi: nil) }

        it 'returns forbidden' do
          get '/mobile/v0/military-service-history', headers: sis_headers

          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'with multiple military service episodes' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_histories_200') do
            get '/mobile/v0/military-service-history', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_multi)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'with one military service episode' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_history_200') do
            get '/mobile/v0/military-service-history', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_single)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'military service episode with no end date' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_histories_200_no_end_date') do
            get '/mobile/v0/military-service-history', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_no_end_date)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'with an empty military service episode' do
        it 'matches the mobile service history schema' do
          VCR.use_cassette('mobile/va_profile/post_read_service_history_200_empty') do
            get '/mobile/v0/military-service-history', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_body_empty)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'when military history discharge codes are missing or null' do
        it 'sets discharge values to nil' do
          VCR.use_cassette('mobile/va_profile/post_read_service_histories_200_no_discharge_code') do
            get '/mobile/v0/military-service-history', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_no_discharge)
            expect(response.body).to match_json_schema('mobile_service_history_response')
          end
        end
      end

      context 'when military history discharge code is unknown' do
        it 'logs an error and sets discharge values to nil' do
          VCR.use_cassette('mobile/va_profile/post_read_service_histories_200_unknown_discharge_code') do
            get '/mobile/v0/military-service-history', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_unknown_discharge)
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
