# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::Client do
  let(:user) { build(:user) }

  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::Client).to receive(:connection).and_return(conn)
  end

  context 'prod settings' do
    it 'returns both subscription keys in headers' do
      headers =
        {
          'Content-Type' => 'application/json',
          'Ocp-Apim-Subscription-Key-E' => 'e_key',
          'Ocp-Apim-Subscription-Key-S' => 's_key'
        }

      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.travel_pay,
                      { subscription_key_e: 'e_key', subscription_key_s: 's_key' }) do
          expect(subject.send(:claim_headers)).to eq(headers)
        end
      end
    end
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
      client = TravelPay::Client.new
      token = client.request_veis_token

      expect(token).to eq('fake_veis_token')
      @stubs.verify_stubbed_calls
    end
  end

  context 'request_btsss_token' do
    let(:vagov_token) { 'fake_vagov_token' }
    let(:json_request_body) { { authJwt: 'fake_vagov_token' }.to_json }

    it 'returns btsss token from proper endpoint' do
      @stubs.post('/api/v1/Auth/access-token', json_request_body) do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"data": {"accessToken": "fake_btsss_token"}}'
        ]
      end

      client = TravelPay::Client.new
      token = client.request_btsss_token('fake_veis_token', vagov_token)

      expect(token).to eq('fake_btsss_token')
      @stubs.verify_stubbed_calls
    end
  end

  context '/claims' do
    before do
      allow_any_instance_of(TravelPay::Client)
        .to receive(:request_veis_token)
        .and_return('veis_token')
      allow_any_instance_of(TravelPay::Client)
        .to receive(:request_sts_token)
        .and_return('sts_token')
      allow_any_instance_of(TravelPay::Client)
        .to receive(:request_btsss_token)
        .with('veis_token', 'sts_token')
        .and_return('btsss_token')
    end

    it 'returns response from claims endpoint' do
      @stubs.get('/api/v1/claims') do
        [
          200,
          {},
          {
            'data' => [
              {
                'id' => 'uuid1',
                'claimNumber' => 'TC0000000000001',
                'claimStatus' => 'InProgress',
                'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
                'facilityName' => 'Cheyenne VA Medical Center',
                'createdOn' => '2024-03-22T21:22:34.465Z',
                'modifiedOn' => '2024-01-01T16:44:34.465Z'
              },
              {
                'id' => 'uuid2',
                'claimNumber' => 'TC0000000000002',
                'claimStatus' => 'InProgress',
                'appointmentDateTime' => '2024-03-01T16:45:34.465Z',
                'facilityName' => 'Cheyenne VA Medical Center',
                'createdOn' => '2024-02-22T21:22:34.465Z',
                'modifiedOn' => '2024-03-01T00:00:00.0Z'
              },
              {
                'id' => 'uuid3',
                'claimNumber' => 'TC0000000000002',
                'claimStatus' => 'Incomplete',
                'appointmentDateTime' => '2024-02-01T16:45:34.465Z',
                'facilityName' => 'Cheyenne VA Medical Center',
                'createdOn' => '2024-01-22T21:22:34.465Z',
                'modifiedOn' => '2024-02-01T00:00:00.0Z'
              }
            ]
          }
        ]
      end

      expected_ids = %w[uuid1 uuid2 uuid3]

      client = TravelPay::Client.new
      claims_response = client.get_claims(user)
      actual_claim_ids = claims_response.body['data'].pluck('id')

      expect(actual_claim_ids).to eq(expected_ids)
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
      private_key_file = Settings.sign_in.sts_client.key_path
      private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file))
      jwt = JWT.encode(assertion, private_key, 'RS256')
      @stubs.post("http:/v0/sign_in/token?assertion=#{jwt}&grant_type=#{grant_type}") do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"data": {"access_token": "fake_sts_token"}}'
        ]
      end
      client = TravelPay::Client.new
      sts_token = client.request_sts_token(user)
      expect(sts_token).to eq('fake_sts_token')
      @stubs.verify_stubbed_calls
    end
  end
end
