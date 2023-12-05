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
      let(:unauth_response) { Faraday::Response.new(body:, status: 401) }

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
          post '/check_in/v2/sessions', **session_params
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          get "/check_in/v2/patient_check_ins/#{id}"
        end
      end

      it 'enqueues the submission job and returns 202' do
        expect do
          post '/check_in/v0/travel_claims', params: post_params
        end.to change(CheckIn::TravelClaimSubmissionWorker.jobs, :size).by(1)
        expect(response.status).to eq(202)
        expect(response.body).to be_blank
      end
    end
  end
end
