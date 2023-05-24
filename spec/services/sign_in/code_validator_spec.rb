# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeValidator do
  describe '#perform' do
    subject do
      SignIn::CodeValidator.new(code:,
                                code_verifier:,
                                client_assertion:,
                                client_assertion_type:,
                                grant_type:).perform
    end

    let(:code) { 'some-code' }
    let(:code_verifier) { 'some-code-verifier' }
    let(:client_assertion) { 'some-client-assertion' }
    let(:client_assertion_type) { 'some-client-assertion-type' }
    let(:grant_type) { 'some-grant-type' }

    context 'when code container that matches code does not exist' do
      let(:code) { 'some-arbitrary-code' }
      let(:expected_error) { SignIn::Errors::CodeInvalidError }
      let(:expected_error_message) { 'Code is not valid' }

      it 'raises a code invalid error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when code does match an existing code container' do
      let!(:code_container) do
        create(:code_container,
               code: code_container_code,
               code_challenge:,
               client_id:,
               user_verification_id:)
      end
      let(:client_id) { client_config.client_id }
      let(:client_config) { create(:client_config, pkce:, certificates: [client_assertion_certificate]) }
      let(:pkce) { true }
      let(:code_container_code) { code }
      let(:client_assertion_certificate) { nil }
      let(:code_challenge) { 'some-code-challenge' }
      let(:user_verification_id) { 'some-user-verification-uuid' }

      context 'and grant type does not match the supported grant type' do
        let(:grant_type) { 'some-arbitrary-grant-type' }
        let(:expected_error) { SignIn::Errors::GrantTypeValueError }
        let(:expected_error_message) { 'Grant Type is not valid' }

        it 'raises a grant type value error' do
          expect { subject }.to raise_exception(expected_error, expected_error_message)
        end
      end

      context 'and grant type does match the supported grant type' do
        let(:grant_type) { SignIn::Constants::Auth::GRANT_TYPE }

        context 'and client is configured with pkce authentication type' do
          let(:pkce) { true }

          context 'and code verifier does not match code challenge in code container' do
            let(:code_verifier) { 'some-arbitrary-code-verifier' }
            let(:expected_error) { SignIn::Errors::CodeChallengeMismatchError }
            let(:expected_error_message) { 'Code Verifier is not valid' }

            it 'raises a code challenge mismatch error' do
              expect { subject }.to raise_exception(expected_error, expected_error_message)
            end
          end

          context 'and code verifier does match the code challenge in the code container' do
            let(:code_verifier) { 'some-code-verifier' }
            let(:code_challenge) do
              unsafe_code_challenge = Digest::SHA256.base64digest(code_verifier)
              Base64.urlsafe_encode64(Base64.urlsafe_decode64(unsafe_code_challenge.to_s), padding: false)
            end

            context 'and user verification uuid in code container does not match with a user verification' do
              let(:user_verification_id) { 'some-arbitrary-user-verification-uuid' }
              let(:expected_error) { ActiveRecord::RecordNotFound }
              let(:expected_error_message) { "Couldn't find UserVerification with 'id'=#{user_verification_id}" }

              it 'raises a user verification not found error' do
                expect { subject }.to raise_exception(expected_error, expected_error_message)
              end
            end

            context 'and user verification uuid in code container does match an existing user verification' do
              let(:user_verification) { create(:user_verification) }
              let(:user_verification_id) { user_verification.id }
              let(:expected_email) { code_container.credential_email }
              let(:expected_client_config) { SignIn::ClientConfig.find_by(client_id: code_container.client_id) }
              let(:expected_validated_credential) do
                SignIn::ValidatedCredential.new(user_verification:,
                                                credential_email: expected_email,
                                                client_id: expected_client_id)
              end

              it 'returns a validated credential object with expected attributes' do
                expect(subject).to have_attributes(credential_email: expected_email,
                                                   client_config: expected_client_config,
                                                   user_verification:)
              end

              it 'returns a validated credential object with expected credential email' do
                expect(subject.credential_email).to eq(expected_email)
              end

              it 'returns a validated credential object with expected client_config' do
                expect(subject.client_config).to eq(expected_client_config)
              end
            end
          end
        end

        context 'and client is configured with private key jwt authentication type' do
          let(:pkce) { false }
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
          let(:client_assertion) do
            JWT.encode(client_assertion_payload, private_key, client_assertion_encode_algorithm)
          end
          let(:certificate_path) { 'spec/fixtures/sign_in/sample_client.crt' }
          let(:client_assertion_certificate) { File.read(certificate_path) }

          context 'and client assertion type does not equal expected value' do
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
              let(:client_assertion) do
                JWT.encode(client_assertion_payload, private_key, client_assertion_encode_algorithm)
              end

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

                    context 'and user verification uuid in code container does not match with a user verification' do
                      let(:user_verification_id) { 'some-arbitrary-user-verification-uuid' }
                      let(:expected_error) { ActiveRecord::RecordNotFound }
                      let(:expected_error_message) do
                        "Couldn't find UserVerification with 'id'=#{user_verification_id}"
                      end

                      it 'raises a user verification not found error' do
                        expect { subject }.to raise_exception(expected_error, expected_error_message)
                      end
                    end

                    context 'and user verification uuid in code condainter does match an existing user verification' do
                      let(:user_verification) { create(:user_verification) }
                      let(:user_verification_id) { user_verification.id }
                      let(:expected_email) { code_container.credential_email }
                      let(:expected_client_config) { SignIn::ClientConfig.find_by(client_id: code_container.client_id) }
                      let(:expected_validated_credential) do
                        SignIn::ValidatedCredential.new(user_verification:,
                                                        credential_email: expected_email,
                                                        client_id: expected_client_id)
                      end

                      it 'returns a validated credential object with expected attributes' do
                        expect(subject).to have_attributes(credential_email: expected_email,
                                                           client_config: expected_client_config,
                                                           user_verification:)
                      end

                      it 'returns a validated credential object with expected credential email' do
                        expect(subject.credential_email).to eq(expected_email)
                      end

                      it 'returns a validated credential object with expected client_config' do
                        expect(subject.client_config).to eq(expected_client_config)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      it 'destroys the found code container regardless of errors raised' do
        expect { try(subject) }.to raise_error(StandardError)
          .and change { SignIn::CodeContainer.find(code_container_code) }.to(nil)
      end
    end
  end
end
