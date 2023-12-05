# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Service do
  subject { described_class }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in:)).to be_an_instance_of(described_class)
    end
  end

  describe '#initialize' do
    it 'has a check_in session' do
      expect(subject.build(check_in:).check_in).to be_a(CheckIn::V2::Session)
    end

    it 'has a redis client' do
      expect(subject.build(check_in:).redis_client).to be_a(TravelClaim::RedisClient)
    end
  end

  describe '#token' do
    let(:access_token) { 'test-token-123' }

    context 'when it exists in redis' do
      before do
        allow_any_instance_of(TravelClaim::RedisClient).to receive(:token).and_return(access_token)
      end

      it 'returns token from redis' do
        expect(subject.build.token).to eq(access_token)
      end
    end

    context 'when it does not exist in redis' do
      before do
        expect_any_instance_of(TravelClaim::Client).to receive(:token)
          .and_return(Faraday::Response.new(body: { access_token: }.to_json, status: 200))
      end

      it 'returns token by calling client' do
        expect(subject.build.token).to eq(access_token)
      end
    end
  end

  describe '#submit_claim' do
    context 'when token does not exist in redis and endpoint fails' do
      let(:response) do
        { data: { error: true, code: 'CLM_020_INVALID_AUTH', message: 'Unauthorized' }, status: 401 }
      end

      before do
        allow_any_instance_of(TravelClaim::RedisClient).to receive(:token).and_return(nil)
        allow_any_instance_of(TravelClaim::Service).to receive(:token).and_return(nil)
      end

      it 'returns 401 error response' do
        expect(subject.build.submit_claim).to eq(response)
      end
    end

    context 'when valid token exists' do
      let(:access_token) { 'test-token-123' }
      let(:claims_json) do
        { claimNumber: 'TC202207000011666' }
      end
      let(:appointment_identifiers) do
        {
          data: {
            id: uuid,
            type: :appointment_identifier,
            attributes: { patientDFN: '123', stationNo: 888, icn: '7892357463V984537' }
          }
        }
      end
      let(:faraday_response) { Faraday::Response.new(body: claims_json, status: 200) }

      let(:submit_claim_response) { { data: claims_json.merge(code: 'CLM_000_SUCCESS'), status: 200 } }

      before do
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache'
        )

        allow_any_instance_of(TravelClaim::RedisClient).to receive(:token).and_return(access_token)
        allow_any_instance_of(TravelClaim::Client).to receive(:submit_claim).and_return(faraday_response)
      end

      it 'returns response from claim api' do
        expect(subject.build(check_in:,
                             params: { appointment_date: '2020-10-16' }).submit_claim).to eq(submit_claim_response)
      end
    end
  end
end
