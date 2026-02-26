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

  describe '#mobile_client?' do
    context 'when client is SM::Client' do
      it 'returns false' do
        expect(client.mobile_client?).to be false
      end
    end

    context 'when client is Mobile::V0::Messaging::Client' do
      let(:mobile_client) { instance_double(Mobile::V0::Messaging::Client) }

      before do
        allow(mobile_client).to receive(:instance_of?).with(Mobile::V0::Messaging::Client).and_return(true)
      end

      it 'returns true for mobile client instance' do
        expect(mobile_client.instance_of?(Mobile::V0::Messaging::Client)).to be true
      end
    end
  end

  describe '#my_health_client?' do
    context 'when client is SM::Client' do
      it 'returns true' do
        expect(client.my_health_client?).to be true
      end
    end

    context 'when client is Mobile::V0::Messaging::Client' do
      let(:mobile_client) { instance_double(Mobile::V0::Messaging::Client) }

      before do
        allow(mobile_client).to receive(:instance_of?).with(SM::Client).and_return(false)
      end

      it 'returns false for mobile client instance' do
        expect(mobile_client.instance_of?(SM::Client)).to be false
      end
    end
  end

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

  describe '#track_with_status' do
    before do
      allow(client).to receive(:mobile_client?).and_return(false)
    end

    context 'when the block succeeds' do
      it 'returns the block result and tracks a success metric' do
        expect(StatsD).to receive(:increment).with(
          'mhv.sm.api.client.some_operation',
          tags: ['platform:web', 'ehr_source:vista', 'status:success']
        )

        result = client.send(:track_with_status, 'some_operation') { 'ok' }
        expect(result).to eq('ok')
      end
    end

    context 'when the block raises an exception' do
      let(:error) { StandardError.new('something went wrong') }

      it 'logs the exception to Sentry with the metric key context' do
        allow(StatsD).to receive(:increment)

        expect(client).to receive(:log_exception_to_sentry).with(
          error, { metric_key: 'some_operation' }, {}, 'error'
        )

        expect { client.send(:track_with_status, 'some_operation') { raise error } }
          .to raise_error(StandardError, 'something went wrong')
      end

      it 'tracks a failure metric' do
        allow(client).to receive(:log_exception_to_sentry)

        expect(StatsD).to receive(:increment).with(
          'mhv.sm.api.client.some_operation',
          tags: ['platform:web', 'ehr_source:vista', 'status:failure']
        )

        expect { client.send(:track_with_status, 'some_operation') { raise error } }
          .to raise_error(StandardError)
      end

      it 're-raises the original exception after logging' do
        allow(client).to receive(:log_exception_to_sentry)
        allow(StatsD).to receive(:increment)

        expect { client.send(:track_with_status, 'some_operation') { raise error } }
          .to raise_error(error)
      end
    end

    context 'when is_oh is true' do
      let(:error) { StandardError.new('oh error') }

      it 'passes is_oh tag to the failure metric' do
        allow(client).to receive(:log_exception_to_sentry)

        expect(StatsD).to receive(:increment).with(
          'mhv.sm.api.client.some_operation',
          tags: ['platform:web', 'ehr_source:oracle_health', 'status:failure']
        )

        expect { client.send(:track_with_status, 'some_operation', is_oh: true) { raise error } }
          .to raise_error(StandardError)
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
