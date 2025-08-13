# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AuthManager do
  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:session) { CheckIn::V2::Session.build(data: { uuid: }) }

  describe '#authorize' do
    it 'raises when ICN is missing and no session provided' do
      service = described_class.new
      expect { service.authorize }.to raise_error(ArgumentError, /ICN not available/)
    end

    it 'raises when ICN is missing in Redis with session provided' do
      allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return(nil)
      service = described_class.new(check_in_session: session)
      expect { service.authorize }.to raise_error(ArgumentError, /ICN not available/)
    end

    it 'fetches veis and v4 tokens and returns the v4 token (with provided icn)' do
      icn = '123V456'
      veis_resp = Faraday::Response.new(response_body: { access_token: 'veis' }.to_json, status: 200)
      v4_resp = Faraday::Response.new(response_body: { data: { accessToken: 'v4' } }.to_json, status: 200)

      service = described_class.new
      allow(service).to receive(:veis_token).and_return(veis_resp)
      allow(service).to receive(:system_access_token_v4).with(veis_access_token: 'veis', icn:).and_return(v4_resp)

      token = service.authorize(icn:)
      expect(token).to eq('v4')
    end

    it 'resolves icn from Redis when not passed' do
      allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return('123V456')
      veis_resp = Faraday::Response.new(response_body: { access_token: 'veis' }.to_json, status: 200)
      v4_resp = Faraday::Response.new(response_body: { data: { accessToken: 'v4' } }.to_json, status: 200)

      service = described_class.new(check_in_session: session)
      allow(service).to receive(:veis_token).and_return(veis_resp)
      allow(service).to receive(:system_access_token_v4).with(veis_access_token: 'veis',
                                                              icn: '123V456').and_return(v4_resp)

      token = service.authorize
      expect(token).to eq('v4')
    end
  end
end
