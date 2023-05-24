# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ClientAssertionValidator do
  describe '#perform' do
    subject { SignIn::ClientAssertionValidator.new(client_assertion:, client_assertion_type:, client_config:).perform }

    let(:private_key) { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
    let(:private_key_path) { 'spec/fixtures/sign_in/sample_client.pem' }
    let(:client_assertion_payload) do
      {
        iss:,
        aud:,
        sub:,
        jti:,
        exp:
      }
    end
    let(:iss) { 'some-iss' }
    let(:aud) { 'some-aud' }
    let(:sub) { 'some-sub' }
    let(:jti) { 'some-jti' }
    let(:exp) { 1.month.since.to_i }
    let(:client_assertion_encode_algorithm) { SignIn::Constants::Auth::CLIENT_ASSERTION_ENCODE_ALGORITHM }
    let(:client_assertion) { JWT.encode(client_assertion_payload, private_key, client_assertion_encode_algorithm) }
    let(:client_assertion_type) { 'some-client-assertion-type' }
    let(:client_id) { client_config.client_id }
    let(:client_config) { create(:client_config, certificates: [client_assertion_certificate]) }
    let(:certificate_path) { 'spec/fixtures/sign_in/sample_client.crt' }
    let(:client_assertion_certificate) { File.read(certificate_path) }

    context 'when client assertion type does not equal expected value' do
      let(:client_assertion_type) { 'some-client-assertion-type' }
      let(:expected_error) { SignIn::Errors::ClientAssertionTypeInvalidError }
      let(:expected_error_message) { 'Client assertion type is not valid' }

      it 'raises client assertion type invalid error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when client assertion type equals expected value' do
      let(:client_assertion_type) { SignIn::Constants::Auth::CLIENT_ASSERTION_TYPE }

      context 'and jwt was not encoded with expected signature' do
        let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:expected_error) { SignIn::Errors::ClientAssertionSignatureMismatchError }
        let(:expected_error_message) { 'Client assertion body does not match signature' }

        it 'raises client assertion signature mismatch error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and jwt is expired' do
        let(:exp) { 1.month.ago.to_i }
        let(:expected_error) { SignIn::Errors::ClientAssertionExpiredError }
        let(:expected_error_message) { 'Client assertion has expired' }

        it 'raises client assertion malformed error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and jwt was not properly encoded' do
        let(:client_assertion) { JWT.encode(client_assertion_payload, nil) }
        let(:expected_error) { SignIn::Errors::ClientAssertionMalformedJWTError }
        let(:expected_error_message) { 'Client assertion is malformed' }

        it 'raises client assertion malformed error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and jwt is valid' do
        let(:client_assertion) { JWT.encode(client_assertion_payload, private_key, client_assertion_encode_algorithm) }

        context 'and iss does not equal client id' do
          let(:iss) { 'some-iss' }
          let(:expected_error) { SignIn::Errors::ClientAssertionAttributesError }
          let(:expected_error_message) { 'Client assertion issuer is not valid' }

          it 'raises client assertion attributes error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end

        context 'and iss equals client id' do
          let(:iss) { client_id }

          context 'and sub does not equal client id' do
            let(:sub) { 'some-sub' }
            let(:expected_error) { SignIn::Errors::ClientAssertionAttributesError }
            let(:expected_error_message) { 'Client assertion subject is not valid' }

            it 'raises client assertion attributes error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end

          context 'and sub equals client id' do
            let(:sub) { client_id }

            context 'and aud does not equal token route' do
              let(:aud) { 'some-aud' }
              let(:expected_error) { SignIn::Errors::ClientAssertionAttributesError }
              let(:expected_error_message) { 'Client assertion audience is not valid' }

              it 'raises client assertion attributes error' do
                expect { subject }.to raise_error(expected_error, expected_error_message)
              end
            end

            context 'and aud equals token route' do
              let(:aud) { "https://#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }

              it 'does not return an error' do
                expect { subject }.not_to raise_error
              end
            end
          end
        end
      end
    end
  end
end
