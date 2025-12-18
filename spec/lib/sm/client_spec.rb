# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'sm/configuration'

describe SM::Client do
  before do
    VCR.use_cassette('sm_client/session') do
      @client ||= begin
        client = SM::Client.new(session: { user_id: '10616687' })
        client.authenticate
        client
      end
    end
  end

  let(:client) { @client }

  describe '#oh_pilot_user?' do
    let(:user) { build(:user, :mhv) }

    before do
      allow(client).to receive(:current_user).and_return(user)
    end

    context 'when user has cerner pilot feature enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, user).and_return(true)
      end

      it 'returns true' do
        expect(client.oh_pilot_user?).to be true
      end
    end

    context 'when user does not have cerner pilot feature enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, user).and_return(false)
      end

      it 'returns false' do
        expect(client.oh_pilot_user?).to be false
      end
    end

    context 'when current_user is nil' do
      before do
        allow(client).to receive(:current_user).and_return(nil)
      end

      it 'returns false' do
        expect(client.oh_pilot_user?).to be false
      end
    end
  end

  describe 'Test new API gateway methods' do
    let(:config) { SM::Configuration.instance }

    before do
      allow(Settings.mhv.sm).to receive(:x_api_key).and_return('test-api-key')
    end

    it 'returns the x-api-key header' do
      result = client.send(:auth_headers)
      headers = { 'base-header' => 'value', 'appToken' => 'test-app-token', 'mhvCorrelationId' => '10616687' }
      allow(client).to receive(:auth_headers).and_return(headers)
      expect(result).to include('x-api-key' => 'test-api-key')
      expect(config.x_api_key).to eq('test-api-key')
    end
  end
end
