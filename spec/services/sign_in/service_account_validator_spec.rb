# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountValidator do
  describe '#perform' do
    subject do
      SignIn::ServiceAccountValidator.new(service_account_assertion:,
                                          grant_type:).perform
    end

    let(:service_account_assertion) do
      JWT.encode(service_account_assertion_payload, private_key, assertion_encode_algorithm)
    end
    let(:grant_type) { SignIn::Constants::Auth::JWT_BEARER }
    let(:service_account_assertion_payload) do
      { iss:, aud:, sub:, jti:, iat:, exp:, scopes:, service_account_id: }
    end
    let(:iss) { 'http://identity-dashboard-api-dev.vfs.va.gov' }
    let(:scheme) { Settings.vsp_environment == 'localhost' ? 'http://' : 'https://' }
    let(:aud) { "#{scheme}#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }
    let(:sub) { 'some-user-email@va.gov' }
    let(:jti) { 'some-jti' }
    let(:iat) { Time.now.to_i }
    let(:exp) { iat + 300 }
    let(:scopes) { ['https://dev-api.va.gov/v0/sign_in/client_config'] }
    let(:service_account_id) { service_account_config.service_account_id }
    let(:private_key) { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
    let(:private_key_path) { 'spec/fixtures/sign_in/sample_service_account.pem' }
    let(:assertion_encode_algorithm) { SignIn::Constants::Auth::CLIENT_ASSERTION_ENCODE_ALGORITHM }
    let(:certificate_path) { 'spec/fixtures/sign_in/sample_service_account_public.pem' }
    let(:service_account_assertion_certificate) { File.read(certificate_path) }
    let(:service_account_config) do
      create(:service_account_config, certificates: [service_account_assertion_certificate])
    end
    let(:expected_error) { SignIn::Errors::ServiceAccountAssertionAttributesError }

    shared_examples 'error response' do
      it 'raises a grant type value error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when grant type does not match the supported grant type' do
      let(:grant_type) { 'some-arbitrary-grant-type' }
      let(:expected_error) { SignIn::Errors::GrantTypeValueError }
      let(:expected_error_message) { 'Grant Type is not valid' }

      it_behaves_like 'error response'
    end

    context 'when grant type does match the supported grant type' do
      context 'when service_account_assertion is not a valid jwt' do
        let(:service_account_assertion) { 'some-service-account-assertion' }
        let(:expected_error) { SignIn::Errors::ServiceAccountAssertionMalformedJWTError }
        let(:expected_error_message) { 'Service account assertion is malformed' }

        it_behaves_like 'error response'
      end

      context 'when service_account_assertion is a valid jwt' do
        context 'when jwt does not contain a valid ServiceAccountConfig id' do
          let(:service_account_id) { SecureRandom.hex }
          let(:expected_error) { SignIn::Errors::ServiceAccountConfigNotFound }
          let(:expected_error_message) { 'Service account config not found' }

          it_behaves_like 'error response'
        end

        context 'when jwt contains a valid ServiceAccountConfig id' do
          it 'calls the ServiceAccountAssertionValidator service' do
            expect_any_instance_of(SignIn::ServiceAccountAssertionValidator).to receive(:perform)
            subject
          end

          context 'when service_account_assertion issuer does not match service account config audience' do
            let(:iss) { 'some-jwt-issuer' }
            let(:expected_error_message) { 'Service account assertion issuer is not valid' }

            it_behaves_like 'error response'
          end

          context 'when service_account_assertion audience does not match SiS token route' do
            let(:aud) { 'some-jwt-aud' }
            let(:expected_error_message) { 'Service account assertion audience is not valid' }

            it_behaves_like 'error response'
          end

          context 'when service_account_assertion scopes are not present in service account config scopes' do
            let(:scopes) { ['https://dev-api.va.gov/v0/sign_in/client_config', 'some-other-scope'] }
            let(:expected_error_message) { 'Service account assertion scopes are not valid' }

            it_behaves_like 'error response'
          end

          context 'when jwt asserted values pass validation' do
            it 'returns the decoded_service_account_assertion' do
              expect(subject.class).to eq(OpenStruct)
              expect(subject.iss).to eq(iss)
              expect(subject.aud).to eq(aud)
              expect(subject.sub).to eq(sub)
              expect(subject.jti).to eq(jti)
              expect(subject.exp).to eq(exp)
              expect(subject.scopes).to eq(scopes)
              expect(subject.service_account_id).to eq(service_account_id)
            end
          end
        end
      end
    end
  end
end
