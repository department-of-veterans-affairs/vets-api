# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  let(:user) { double('User', account_uuid: '12345') }
  let(:service) { described_class.new(user) }
  let(:path) { '/some/path' }
  let(:params) { { key: 'value' } }
  let(:headers) { { 'Custom-Header' => 'value' } }
  let(:options) { { timeout: 5 } }
  let(:mock_response) { double('Response', success?: true) }
  let(:mock_user_service) { double('UserService', extend_session: true) }

  before do
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token, user).and_return(false)
    allow(RequestStore.store).to receive(:[]).with('request_id').and_return('request-id')
    allow(service).to receive_messages(user_service: mock_user_service, perform: mock_response)
  end

  describe '#initialize' do
    it 'sets the user' do
      expect(service.user).to eq(user)
    end
  end

  describe '#perform' do
    it 'does not extend the session if STS_OAUTH_TOKEN is enabled' do
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token, user).and_return(true)
      response = service.send(:perform, :get, path, params, headers, options)
      expect(response).to eq(mock_response)
      expect(mock_user_service).not_to have_received(:extend_session)
    end
  end

  describe '#headers' do
    it 'returns the correct headers' do
      expected_headers = {
        'Authorization' => 'Bearer 1234',
        'Content-Type' => 'application/json',
        'X-Request-ID' => 'request-id'
      }
      expect(service.send(:headers)).to eq(expected_headers)
    end
  end

  describe '#config' do
    it 'returns the Eps configuration instance' do
      expect(service.send(:config)).to eq(Eps::Configuration.instance)
    end
  end
end
