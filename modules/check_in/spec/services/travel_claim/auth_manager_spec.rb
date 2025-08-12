# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AuthManager do
  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:session) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  it 'raises when ICN is missing' do
    allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return(nil)
    expect { described_class.new(check_in_session: session).authorize }.to raise_error(ArgumentError)
  end

  it 'returns cached token when present' do
    allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return('123V456')
    Rails.cache.write('travel_pay_v4_token:123V456', 'cached-token', namespace: 'check-in-travel-pay-cache',
                                                                     expires_in: 300)

    token = described_class.new(check_in_session: session).authorize
    expect(token).to eq('cached-token')
  end

  it 'fetches veis and v4 tokens and caches the result' do
    allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return('123V456')

    veis_resp = Faraday::Response.new(response_body: { access_token: 'veis' }.to_json, status: 200)
    v4_resp = Faraday::Response.new(response_body: { data: { accessToken: 'v4' } }.to_json, status: 200)

    service = described_class.new(check_in_session: session)
    allow(service).to receive(:veis_token).and_return(veis_resp)
    allow(service).to receive(:system_access_token_v4).with(veis_access_token: 'veis',
                                                            icn: '123V456').and_return(v4_resp)

    token = service.authorize
    expect(token).to eq('v4')

    cached = Rails.cache.read('travel_pay_v4_token:123V456', namespace: 'check-in-travel-pay-cache')
    expect(cached).to eq('v4')
  end
end
