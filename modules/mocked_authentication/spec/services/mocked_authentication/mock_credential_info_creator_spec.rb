# frozen_string_literal: true

require 'rails_helper'

describe MockedAuthentication::MockCredentialInfoCreator do
  subject { described_class.new(credential_info: credential_info).perform }

  let(:credential_info) { { type: 'logingov' }.to_json }

  describe '#perform' do
    context 'with valid credential_info' do
      it 'does not raise an error' do
        expect { subject }.not_to raise_error
      end

      it 'returns a MockCredentialInfo object' do
        expect(subject).to be_a(MockedAuthentication::MockCredentialInfo)
      end
    end

    context 'with invalid credential_info' do
      context 'with missing CSP type' do
        let(:credential_info) { { type: '' }.to_json }

        it 'raises an error' do
          expect { subject }.to raise_error(StandardError, 'CSP type required')
        end
      end

      context 'with incorrect CSP type' do
        let(:credential_info) { { type: 'bad_csp' }.to_json }

        it 'raises an error' do
          expect { subject }.to raise_error(StandardError, 'Invalid CSP Type')
        end
      end
    end
  end
end
