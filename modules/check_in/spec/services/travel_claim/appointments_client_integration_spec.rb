# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AppointmentsClient, type: :integration do
  let(:client) { described_class.new }
  let(:claim_id) { 'a1178d06-ec2f-400c-fa9e-77e479fc5ef8' }
  let(:correlation_id) { 'a1178d06-ec2f-400c-fa9e-77e479fc5ef8' }

  before do
    allow(Settings).to receive(:vsp_environment).and_return('test')
    allow(client).to receive(:settings).and_return(
      double('Settings',
             claims_url_v2: 'https://dev.integration.d365.va.gov',
             subscription_key: 'fake_subscription_key')
    )
  end

  describe '#submit_claim_v3' do
    context 'when the API returns success' do
      it 'returns successful response' do
        VCR.use_cassette('check_in/btsss/submit_claim_v3/submit_claim_v3_200', match_requests_on: %i[method uri]) do
          response = client.submit_claim_v3(claim_id:, correlation_id:)

          expect(response).to be_a(Faraday::Env)
          expect(response.status).to eq(200)
          expect(response.body['data']['claimId']).to eq(claim_id)
          expect(response.body['data']['status']).to eq('submitted')
        end
      end
    end

    context 'when the API returns bad request (claim already submitted)' do
      it 'returns error response' do
        VCR.use_cassette('check_in/btsss/submit_claim_v3/submit_claim_v3_400', match_requests_on: %i[method uri]) do
          expect do
            client.submit_claim_v3(claim_id:, correlation_id:)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'when the API returns not found (claim does not exist)' do
      it 'returns error response' do
        VCR.use_cassette('check_in/btsss/submit_claim_v3/submit_claim_v3_404', match_requests_on: %i[method uri]) do
          expect do
            client.submit_claim_v3(claim_id: 'nonexistent-claim-id', correlation_id:)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'when the API returns server error' do
      it 'returns error response' do
        VCR.use_cassette('check_in/btsss/submit_claim_v3/submit_claim_v3_500', match_requests_on: %i[method uri]) do
          expect do
            client.submit_claim_v3(claim_id:, correlation_id:)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end
