# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AssertionValidator do
  describe '#perform' do
    subject { SignIn::AssertionValidator.new(assertion:).perform }

    let(:private_key) { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
    let(:private_key_path) { 'spec/fixtures/sign_in/sample_service_account.pem' }
    let(:assertion_payload) do
      {
        iss:,
        aud:,
        sub:,
        jti:,
        exp:,
        service_account_id:,
        scopes:
      }
    end
    let(:iss) { 'some-iss' }
    let(:aud) { 'some-aud' }
    let(:sub) { 'some-sub' }
    let(:jti) { 'some-jti' }
    let(:exp) { 1.month.since.to_i }
    let(:scopes) { service_account_config.scopes }
    let(:service_account_id) { service_account_config.service_account_id }
    let(:service_account_config) { create(:service_account_config, certificates: [assertion_certificate]) }
    let(:service_account_audience) { service_account_config.access_token_audience }
    let(:assertion_encode_algorithm) { SignIn::Constants::Auth::ASSERTION_ENCODE_ALGORITHM }
    let(:assertion) { JWT.encode(assertion_payload, private_key, assertion_encode_algorithm) }
    let(:certificate_path) { 'spec/fixtures/sign_in/sample_service_account.crt' }
    let(:assertion_certificate) { File.read(certificate_path) }
    let(:token_route) { "https://#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }

    context 'when jwt was not encoded with expected signature' do
      let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
      let(:expected_error) { SignIn::Errors::AssertionSignatureMismatchError }
      let(:expected_error_message) { 'Assertion body does not match signature' }

      it 'raises assertion signature mismatch error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when jwt is expired' do
      let(:exp) { 1.month.ago.to_i }
      let(:expected_error) { SignIn::Errors::AssertionExpiredError }
      let(:expected_error_message) { 'Assertion has expired' }

      it 'raises assertion malformed error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when jwt was not properly encoded' do
      let(:assertion) { JWT.encode(assertion_payload, nil) }
      let(:expected_error) { SignIn::Errors::AssertionMalformedJWTError }
      let(:expected_error_message) { 'Assertion is malformed' }

      it 'raises assertion malformed error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when jwt is valid' do
      let(:assertion) { JWT.encode(assertion_payload, private_key, assertion_encode_algorithm) }

      context 'and service account config in assertion does not match an existing service account config' do
        let(:service_account_id) { 'some-service-account-id' }
        let(:expected_error) { SignIn::Errors::ServiceAccountConfigNotFound }
        let(:expected_error_message) { 'Service account config not found' }

        it 'raises service account config not found error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and service account config in assertion does match an existing service account config' do
        let(:service_account_id) { service_account_config.service_account_id }

        context 'and iss does not equal service account config audience' do
          let(:iss) { 'some-iss' }
          let(:expected_error) { SignIn::Errors::ServiceAccountAssertionAttributesError }
          let(:expected_error_message) { 'Assertion issuer is not valid' }

          it 'raises service account assertion attributes error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end

        context 'and iss equals service account config audience' do
          let(:iss) { service_account_audience }

          context 'and audience does not match token route' do
            let(:aud) { 'some-aud' }
            let(:expected_error) { SignIn::Errors::ServiceAccountAssertionAttributesError }
            let(:expected_error_message) { 'Assertion audience is not valid' }

            it 'raises service account assertion attributes error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end

          context 'and audience matches token route' do
            let(:aud) { token_route }

            context 'and scopes are not a subset of service account config scopes' do
              let(:scopes) { ['some-scopes'] }
              let(:expected_error) { SignIn::Errors::ServiceAccountAssertionAttributesError }
              let(:expected_error_message) { 'Assertion scopes are not valid' }

              it 'raises service account assertion attributes error' do
                expect { subject }.to raise_error(expected_error, expected_error_message)
              end
            end

            context 'and scopes are a subset of service account config scopes' do
              let(:scopes) { [service_account_config.scopes.first] }

              it 'returns service account access token with expected service account id' do
                expect(subject.service_account_id).to eq(service_account_id)
              end

              it 'returns service account access token with expected audience' do
                expect(subject.audience).to eq(service_account_audience)
              end

              it 'returns service account access token with expected scopes' do
                expect(subject.scopes).to eq(scopes)
              end

              it 'returns service account access token with expected user identifier' do
                expect(subject.user_identifier).to eq(sub)
              end
            end
          end
        end
      end
    end
  end
end
