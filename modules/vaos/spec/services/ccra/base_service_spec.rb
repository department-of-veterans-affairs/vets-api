# frozen_string_literal: true

require 'rails_helper'

describe Ccra::BaseService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }

  describe '#config' do
    it 'returns a Ccra::Configuration instance' do
      expect(subject.config).to be_a(Ccra::Configuration)
    end

    it 'memoizes the configuration' do
      config = subject.config
      expect(subject.config).to equal(config)
    end
  end

  describe '#settings' do
    it 'returns the CCRA settings from VAOS configuration' do
      expect(subject.settings).to eq(Settings.vaos.ccra)
    end
  end

  describe 'headers' do
    let(:request_id) { 'test-request-id' }
    let(:session_token) { 'test-session-token' }

    before do
      RequestStore.store['request_id'] = request_id
      allow_any_instance_of(VAOS::UserService).to receive(:session).with(user).and_return(session_token)
    end

    it 'includes session authentication headers' do
      headers = subject.send(:headers)

      # Should include headers from SessionService
      expect(headers).to include(
        'X-VAMF-JWT' => session_token,
        'X-Request-ID' => request_id
      )

      # Should not include headers from token authentication
      expect(headers).not_to include('Authorization')
    end
  end
end
