# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AuthenticationServiceRetriever do
  describe '#perform' do
    subject { SignIn::AuthenticationServiceRetriever.new(type:, client_config:).perform }

    let(:type) { 'some-type' }
    let(:client_config) { create(:client_config, authentication:) }
    let(:authentication) { SignIn::Constants::Auth::API }

    context 'when client id maps to a mocked authentication configuration' do
      let(:authentication) { SignIn::Constants::Auth::MOCK }
      let(:expected_credential_service) { MockedAuthentication::Credential::Service }

      it 'returns expected credential service object' do
        expect(subject).to be_a(expected_credential_service)
      end

      it 'sets type variable to returned credential service object' do
        expect(subject.type).to eq(type)
      end
    end

    context 'when client id does not map to a mocked authentication configuration' do
      let(:authentication) { SignIn::Constants::Auth::API }

      context 'and type is equal to logingov' do
        let(:type) { SignIn::Constants::Auth::LOGINGOV }
        let(:expected_credential_service) { SignIn::Logingov::Service }

        it 'returns expected credential service object' do
          expect(subject).to be_a(expected_credential_service)
        end
      end

      context 'and type is not equal to logingov' do
        let(:type) { 'some-type' }
        let(:expected_credential_service) { SignIn::Idme::Service }

        it 'returns expected credential service object' do
          expect(subject).to be_a(expected_credential_service)
        end

        it 'sets type variable to returned credential service object' do
          expect(subject.type).to eq(type)
        end
      end
    end
  end
end
