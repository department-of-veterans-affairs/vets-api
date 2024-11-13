# frozen_string_literal: true

require 'rails_helper'
require 'eps/base_service'

RSpec.describe EPS::BaseService do
  let(:user) { double('User', account_uuid: '12345') }
  let(:access_token) { 'fake_access_token' }
  let(:service) { described_class.new(user) }
  let(:path) { '/some/path' }
  let(:params) { { key: 'value' } }
  let(:headers) { { 'Custom-Header' => 'value' } }
  let(:options) { { timeout: 5 } }

  before do
    allow(Flipper).to receive(:enabled?).with(:STS_OAUTH_TOKEN, user).and_return(false)
    allow(RequestStore.store).to receive(:[]).with('request_id').and_return('request-id')
    skip('EPS::TokenService is not implemented yet') unless defined?(EPS::TokenService)
    allow(EPS::TokenService).to receive(:token).and_return(access_token)
  end

  describe '#perform' do
    it 'extends the session if STS_OAUTH_TOKEN is not enabled' do
      expect(service).to receive(:super).with(:get, path, params, headers, options).and.return('response')
      expect(service.user_service).to receive(:extend_session).with(user.account_uuid)
      response = service.send(:perform, :get, path, params, headers, options)
      expect(response).to eq('response')
    end
  end

  describe '#headers' do
    it 'returns the correct headers' do
      expected_headers = {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json',
        'X-Request-ID' => 'request-id'
      }
      expect(service.send(:headers)).to eq(expected_headers)
    end
  end

  describe '#config' do
    it 'returns the EPS configuration instance' do
      expect(service.send(:config)).to eq(EPS::Configuration.instance)
    end
  end
end