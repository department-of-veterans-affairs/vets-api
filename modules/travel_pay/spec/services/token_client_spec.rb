# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::TokenClient do
  let(:user) { build(:user) }

  expected_log_prefix = 'travel_pay.token.response_time'

  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::TokenClient).to receive(:connection).and_return(conn)
    allow(StatsD).to receive(:measure)
  end

  context 'request_veis_token' do
    it 'returns veis token from proper endpoint' do
      tenant_id = Settings.travel_pay.veis.tenant_id
      @stubs.post("#{tenant_id}/oauth2/token") do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"access_token": "fake_veis_token"}'
        ]
      end
      token_client = TravelPay::TokenClient.new(123)
      token = token_client.request_veis_token

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: ['travel_pay:veis'])
      expect(token).to eq('fake_veis_token')
      @stubs.verify_stubbed_calls
    end
  end

  context 'request_btsss_token' do
    before do
      allow_any_instance_of(TravelPay::TokenClient)
        .to receive(:request_sts_token)
        .and_return('sts_token')
    end

    it 'returns btsss token from proper endpoint' do
      @stubs.post('api/v1.2/Auth/access-token') do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"data": {"accessToken": "fake_btsss_token"}}'
        ]
      end

      token_client = TravelPay::TokenClient.new(123)
      token = token_client.request_btsss_token('veis_token', user)

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: ['travel_pay:btsss'])
      expect(token).to eq('fake_btsss_token')
      @stubs.verify_stubbed_calls
    end
  end

  context 'request_sts_token' do
    let(:assertion) do
      {
        'iss' => 'https://www.example.com',
        'sub' => user.email,
        'aud' => 'https://www.example.com/v0/sign_in/token',
        'iat' => 1_634_745_556,
        'exp' => 1_634_745_856,
        'scopes' => [],
        'service_account_id' => nil,
        'jti' => 'c3fa0763-70cb-419a-b3a6-d2563e7b8504',
        'user_attributes' => { 'icn' => '123498767V234859' }
      }
    end
    let(:grant_type) { 'urn:ietf:params:oauth:grant-type:jwt-bearer' }

    before do
      Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
      allow(SecureRandom).to receive(:uuid).and_return('c3fa0763-70cb-419a-b3a6-d2563e7b8504')
    end

    after { Timecop.return }

    it 'builds sts assertion and requests sts token' do
      private_key_file = IdentitySettings.sign_in.sts_client.key_path
      private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file))
      jwt = JWT.encode(assertion, private_key, 'RS256')
      @stubs.post("http:/v0/sign_in/token?assertion=#{jwt}&grant_type=#{grant_type}") do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"data": {"access_token": "fake_sts_token"}}'
        ]
      end
      token_client = TravelPay::TokenClient.new(123)
      sts_token = token_client.request_sts_token(user)
      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: ['travel_pay:sts'])
      expect(sts_token).to eq('fake_sts_token')
      @stubs.verify_stubbed_calls
    end
  end
end
