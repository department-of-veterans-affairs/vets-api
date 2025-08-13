# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TokenClient do
  let(:client) { described_class.new }
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

  before do
    allow(Settings).to receive_message_chain(:check_in, :travel_reimbursement_api_v2).and_return(settings_double)
    allow(Settings).to receive(:vsp_environment).and_return('dev')
  end

  describe '#veis_token' do
    it 'POSTs to the VEIS token endpoint with form-encoded body' do
      url = "#{settings_double.auth_url}/#{settings_double.tenant_id}/oauth2/v2.0/token"
      stub = stub_request(:post, url)
             .to_return(status: 200, body: { access_token: 'veis' }.to_json, headers: { 'Content-Type' => 'application/json' })

      resp = client.veis_token
      expect(resp.status).to eq(200)

      expect(stub).to have_been_requested

      expect(WebMock).to have_requested(:post, url).with { |req|
        expect(req.headers['Content-Type']).to eq('application/x-www-form-urlencoded')
        form = URI.decode_www_form(req.body).to_h
        expect(form).to include(
          'client_id' => settings_double.travel_pay_client_id,
          'client_secret' => settings_double.travel_pay_client_secret,
          'scope' => settings_double.scope,
          'grant_type' => 'client_credentials'
        )
      }
    end
  end

  describe '#system_access_token_v4' do
    it 'POSTs to the v4 system access token endpoint with required headers and body' do
      url = "#{settings_double.claims_url_v2}/api/v4/auth/system-access-token"
      stub = stub_request(:post, url)
             .to_return(status: 200, body: { data: { accessToken: 'v4' } }.to_json, headers: { 'Content-Type' => 'application/json' })

      resp = client.system_access_token_v4(veis_access_token: 'veis', icn: '123V456')
      expect(resp.status).to eq(200)
      expect(stub).to have_been_requested

      expect(WebMock).to have_requested(:post, url).with { |req|
        # Headers
        expect(req.headers['Authorization']).to eq('Bearer veis')
        expect(req.headers['Content-Type']).to eq('application/json')
        expect(req.headers['Ocp-Apim-Subscription-Key']).to eq(settings_double.subscription_key)
        expect(req.headers.keys.any? { |k| k.to_s.casecmp('X-Correlation-ID').zero? }).to be(true)

        # Body
        parsed = JSON.parse(req.body)
        expect(parsed).to include('secret' => settings_double.travel_pay_client_secret, 'icn' => '123V456')
      }
    end

    it 'does not log secrets on error paths' do
      url = "#{settings_double.claims_url_v2}/api/v4/auth/system-access-token"
      stub_request(:post, url).to_return(status: 500, body: { detail: 'boom' }.to_json, headers: { 'Content-Type' => 'application/json' })

      original_logger = Rails.logger
      io = StringIO.new
      Rails.logger = ActiveSupport::Logger.new(io)

      begin
        expect do
          client.system_access_token_v4(veis_access_token: 'veis', icn: '123V456')
        end.to raise_error(Common::Exceptions::BackendServiceException)

        logs = io.string
        # Ensure the client secret marker is not leaked in logs
        expect(logs).not_to include(settings_double.travel_pay_client_secret)
      ensure
        Rails.logger = original_logger
      end
    end
  end
end