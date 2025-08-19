# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TokenClient do
  let(:client_number) { 'cn-123' }
  let(:client) { described_class.new(client_number) }
  let(:settings_double) do
    OpenStruct.new(
      auth_url: 'https://auth.example.test',
      tenant_id: 'tenant-123',
      travel_pay_client_id: 'client-id',
      travel_pay_client_secret: 'super-secret-123',
      scope: 'scope.read',
      claims_url_v2: 'https://claims.example.test',
      service_name: 'check-in-travel-pay',
      mock: false,
      subscription_key: 'sub-key',
      e_subscription_key: 'e-sub',
      s_subscription_key: 's-sub'
    )
  end
  let(:check_in_settings) { OpenStruct.new(travel_reimbursement_api_v2: settings_double) }

  before do
    allow(Settings).to receive_messages(check_in: check_in_settings, vsp_environment: 'dev')
  end

  describe '#veis_token' do
    it 'POSTs to the VEIS token endpoint with form-encoded body' do
      url = "#{settings_double.auth_url}/#{settings_double.tenant_id}/oauth2/v2.0/token"
      stub = stub_request(:post, url)
             .to_return(
               status: 200,
               body: { access_token: 'veis' }.to_json,
               headers: { 'Content-Type' => 'application/json' }
             )

      resp = client.veis_token
      expect(resp.status).to eq(200)

      expect(stub).to have_been_requested

      expect(WebMock).to(have_requested(:post, url).with do |req|
        expect(req.headers['Content-Type']).to eq('application/x-www-form-urlencoded')
        form = URI.decode_www_form(req.body).to_h
        expect(form).to include(
          'client_id' => settings_double.travel_pay_client_id,
          'client_secret' => settings_double.travel_pay_client_secret,
          'scope' => settings_double.scope,
          'grant_type' => 'client_credentials'
        )
      end)
    end

    it 'bubbles errors when VEIS returns non-200' do
      url = "#{settings_double.auth_url}/#{settings_double.tenant_id}/oauth2/v2.0/token"
      stub_request(:post, url).to_return(status: 500, body: { detail: 'err' }.to_json,
                                         headers: { 'Content-Type' => 'application/json' })
      expect do
        client.veis_token
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end

  describe '#system_access_token_v4' do
    it 'POSTs to the v4 system access token endpoint with required headers including client number' do
      url = "#{settings_double.claims_url_v2}/api/v4/auth/system-access-token"
      stub = stub_request(:post, url)
             .to_return(
               status: 200,
               body: { data: { accessToken: 'v4' } }.to_json,
               headers: { 'Content-Type' => 'application/json' }
             )

      resp = client.system_access_token_v4(veis_access_token: 'veis', icn: '123V456')
      expect(resp.status).to eq(200)
      expect(stub).to have_been_requested

      expect(WebMock).to(have_requested(:post, url).with do |req|
        expect(req.headers['Authorization']).to eq('Bearer veis')
        expect(req.headers['Content-Type']).to eq('application/json')
        expect(req.headers['Ocp-Apim-Subscription-Key']).to eq(settings_double.subscription_key)
        client_key = req.headers.keys.find { |k| k.to_s.casecmp('BTSSS-API-Client-Number').zero? }
        expect(client_key).not_to be_nil
        expect(req.headers[client_key]).to eq(client_number)
        expect(req.headers.keys.any? { |k| k.to_s.casecmp('X-Correlation-ID').zero? }).to be(true)

        parsed = JSON.parse(req.body)
        expect(parsed).to include('secret' => settings_double.travel_pay_client_secret, 'icn' => '123V456')
      end)
    end

    it 'uses E/S subscription keys and client number in production' do
      allow(Settings).to receive(:vsp_environment).and_return('production')
      url = "#{settings_double.claims_url_v2}/api/v4/auth/system-access-token"
      stub_request(:post, url).to_return(status: 200, body: { data: { accessToken: 'v4' } }.to_json,
                                         headers: { 'Content-Type' => 'application/json' })
      client.system_access_token_v4(veis_access_token: 'x', icn: 'y')
      expect(WebMock).to(have_requested(:post, url).with do |req|
        expect(req.headers['Ocp-Apim-Subscription-Key-E']).to eq('e-sub')
        expect(req.headers['Ocp-Apim-Subscription-Key-S']).to eq('s-sub')
        client_key = req.headers.keys.find { |k| k.to_s.casecmp('BTSSS-API-Client-Number').zero? }
        expect(client_key).not_to be_nil
        expect(req.headers[client_key]).to eq(client_number)
      end)
    end

    it 'does not log secrets on error paths' do
      url = "#{settings_double.claims_url_v2}/api/v4/auth/system-access-token"
      stub_request(:post, url).to_return(
        status: 500,
        body: { detail: 'boom' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      original_logger = Rails.logger
      io = StringIO.new
      Rails.logger = ActiveSupport::Logger.new(io)

      begin
        expect do
          client.system_access_token_v4(veis_access_token: 'veis', icn: '123V456')
        end.to raise_error(Common::Exceptions::BackendServiceException)

        logs = io.string
        expect(logs).not_to include(settings_double.travel_pay_client_secret)
      ensure
        Rails.logger = original_logger
      end
    end
  end
end
