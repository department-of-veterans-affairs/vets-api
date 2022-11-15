# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::TravelClaims', type: :request do
  let(:id) { '5bcd636c-d4d3-4349-9058-03b2f6b38ced' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled').and_return(true)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_reimbursement')
                                        .and_return(true)

    Rails.cache.clear
  end

  describe 'POST `create`' do
    let(:post_params) { { travel_claims: { uuid: id, appointment_date: '2022-10-22' } } }

    context 'when travel reimbursement feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_reimbursement')
                                            .and_return(false)
      end

      it 'returns routing error' do
        post '/check_in/v0/travel_claims', params: post_params
        expect(response.status).to be(404)
      end
    end

    context 'when session is not authorized' do
      let(:body) { { 'permissions' => 'read.none', 'status' => 'success', 'uuid' => id } }
      let(:unauth_response) { Faraday::Response.new(body: body, status: 401) }

      it 'returns unauthorized response' do
        post '/check_in/v0/travel_claims', params: post_params

        expect(response.body).to eq(unauth_response.body.to_json)
        expect(response.status).to eq(unauth_response.status)
      end
    end

    context 'when session is authorized' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1950-01-27',
              last_name: 'Johnson'
            }
          }
        }
      end

      before do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', session_params
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          get "/check_in/v2/patient_check_ins/#{id}"
        end
      end

      context 'and service returns a success response' do
        let(:response_body) do
          {
            data: {
              value: {
                claimNumber: 'TC202207000011666'
              },
              formatters: [],
              contentTypes: [],
              declaredType: nil,
              statusCode: 200
            },
            status: 200
          }
        end
        let(:resp) { Faraday::Response.new(body: response_body, status: 200) }

        it 'returns a successful response' do
          VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_200', match_requests_on: [:host]) do
            VCR.use_cassette 'check_in/btsss/token/token_200' do
              post '/check_in/v0/travel_claims', params: post_params
            end
          end
          expect(response.status).to eq(resp.status)
          expect(response.body).to eq(resp.body.to_json)
        end
      end

      context 'and service returns a 400 response' do
        let(:response_body) do
          {
            errors: [
              {
                title: 'Bad Request',
                detail: 'Bad Request',
                code: 'BTSSS-API_400',
                status: '400'
              }
            ]
          }
        end
        let(:resp) { Faraday::Response.new(body: response_body, status: 400) }

        it 'returns a failure response' do
          VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_400', match_requests_on: [:host]) do
            VCR.use_cassette 'check_in/btsss/token/token_200' do
              post '/check_in/v0/travel_claims', params: post_params
            end
          end
          expect(response.status).to eq(resp.status)
          expect(response.body).to eq(resp.body.to_json)
        end
      end
    end
  end
end
