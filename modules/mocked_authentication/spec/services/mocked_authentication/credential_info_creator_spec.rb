# frozen_string_literal: true

require 'rails_helper'

describe MockedAuthentication::CredentialInfoCreator do
  describe '#perform' do
    subject { described_class.new(credential_info: credential_info).perform }

    let(:credential_payload) { { 'credential' => 'some-credential' } }
    let(:credential_info) { Base64.encode64(credential_payload.deep_symbolize_keys.to_json) }
    let(:expected_code) { 'some-code' }

    before { allow(SecureRandom).to receive(:hex).and_return(expected_code) }

    it 'returns expected code' do
      expect(subject).to be(expected_code)
    end

    it 'returns code associated with Mock Credential Info object' do
      expect(MockedAuthentication::CredentialInfo.find(subject)).not_to be_nil
    end
  end
end
