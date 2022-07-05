# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CredentialInfoCreator do
  describe '#perform' do
    subject do
      SignIn::CredentialInfoCreator.new(csp_user_attributes: csp_user_attributes,
                                        csp_token_response: csp_token_response).perform
    end

    let(:csp_user_attributes) { { uuid: csp_uuid, sign_in: { service_name: service_name } } }
    let(:csp_token_response) { { id_token: id_token, expires_in: expires_in } }
    let(:service_name) { 'some-service-name' }
    let(:csp_uuid) { 'some-csp-uuid' }
    let(:id_token) { 'some-id-token' }
    let(:expires_in) { 'some-expires-in-value' }

    context 'when authenticated csp is not logingov' do
      let(:service_name) { 'some-service-name' }

      it 'does not create credential info' do
        subject
        expect(SignIn::CredentialInfo.find(csp_uuid)).to be_nil
      end
    end

    shared_examples 'error response' do
      let(:expected_error) { SignIn::Errors::InvalidCredentialInfoError }
      let(:expected_error_message) { 'Cannot save information for malformed credential' }

      it 'raises an invalid credential info error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when authenticated csp is logingov' do
      let(:service_name) { 'logingov' }

      context 'and csp user attributes do not contain uuid' do
        let(:csp_uuid) { nil }

        it_behaves_like 'error response'
      end

      context 'and csp user attributes contain uuid' do
        let(:csp_uuid) { 'some-csp-uuid' }

        context 'and csp token response does not contain id_token' do
          let(:id_token) { nil }

          it_behaves_like 'error response'
        end

        context 'and csp token response contains id_token' do
          let(:id_token) { 'some-id-token' }

          context 'and csp token response does not contain expires_in' do
            let(:expires_in) { nil }
            let(:raised_exception) { Redis::CommandError }

            before { allow_any_instance_of(SignIn::CredentialInfo).to receive(:expire).and_raise(raised_exception) }

            it_behaves_like 'error response'
          end

          context 'and csp token response contains expires_in' do
            let(:expires_in) { 900 }

            it 'creates a credential info redis object with expected attributes' do
              subject
              credential_info = SignIn::CredentialInfo.find(csp_uuid)
              expect(credential_info.csp_uuid).to eq(csp_uuid)
              expect(credential_info.id_token).to eq(id_token)
            end
          end
        end
      end
    end
  end
end
