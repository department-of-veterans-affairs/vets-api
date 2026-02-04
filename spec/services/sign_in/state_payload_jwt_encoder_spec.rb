# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::StatePayloadJwtEncoder do
  describe '#perform' do
    subject do
      SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                         code_challenge_method:,
                                         client_state:,
                                         type:,
                                         acr:,
                                         scope:,
                                         client_config:,
                                         operation:).perform
    end

    let(:code_challenge) { 'some-code-challenge' }
    let(:code_challenge_method) { 'some-code-challenge-method' }
    let(:client_state) { 'some-client-state' }
    let(:acr) { 'some-acr' }
    let(:type) { 'some-type' }
    let(:scope) { nil }
    let(:client_config) { create(:client_config, pkce:, shared_sessions:, authentication:) }
    let(:pkce) { true }
    let(:shared_sessions) { false }
    let(:authentication) { SignIn::Constants::Auth::API }
    let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }
    let(:operation) { SignIn::Constants::Auth::VERIFY_CTA_AUTHENTICATED }

    shared_context 'validated code challenge state payload jwt' do
      let(:code) { 'some-state-code-value' }
      let(:client_id) { client_config.client_id }
      let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
      let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
      let(:client_state) { SecureRandom.alphanumeric(client_state_minimum_length + 1) }
      let(:created_at) { Time.zone.now.to_i }

      before do
        allow(SecureRandom).to receive(:hex).and_return(code)
        Timecop.freeze
      end

      after { Timecop.return }

      shared_context 'properly encoded state payload jwt' do
        it 'returns an encoded jwt value' do
          decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
          expect(decoded_jwt.acr).to eq(acr)
          expect(decoded_jwt.type).to eq(type)
          expect(decoded_jwt.client_id).to eq(client_id)
          expect(decoded_jwt.code_challenge).to eq(code_challenge)
          expect(decoded_jwt.client_state).to eq(client_state)
          expect(decoded_jwt.code).to eq(code)
          expect(decoded_jwt.created_at).to eq(created_at)
          expect(decoded_jwt.scope).to eq(scope)
          expect(decoded_jwt.operation).to eq(operation)
        end

        it 'saves a StateCode in redis' do
          expect { subject }.to change { SignIn::StateCode.find(code) }.from(nil)
        end
      end

      context 'and given scope is set to device_sso' do
        let(:scope) { SignIn::Constants::Auth::DEVICE_SSO }

        context 'and client config is set to API authentication' do
          let(:authentication) { SignIn::Constants::Auth::API }

          context 'and client config is set to enable shared sessions' do
            let(:shared_sessions) { true }

            it_behaves_like 'properly encoded state payload jwt'
          end

          context 'and client config is not set to enable shared sessions' do
            let(:shared_sessions) { false }
            let(:expected_error) { SignIn::Errors::InvalidScope }
            let(:expected_error_message) { 'Scope is not valid for Client' }

            it 'raises an invalid scope error' do
              expect { subject }.to raise_exception(expected_error, expected_error_message)
            end
          end
        end

        context 'and client config is set to COOKIE authentication' do
          let(:authentication) { SignIn::Constants::Auth::COOKIE }
          let(:expected_error) { SignIn::Errors::InvalidScope }
          let(:expected_error_message) { 'Scope is not valid for Client' }

          it 'raises an invalid scope error' do
            expect { subject }.to raise_exception(expected_error, expected_error_message)
          end
        end
      end

      context 'and given acr is not within accepted acr values list' do
        let(:acr) { 'some-arbitrary-acr' }
        let(:expected_error) { SignIn::Errors::StatePayloadError }
        let(:expected_error_message) { 'Attributes are not valid' }

        it 'raises a code challenge state map error' do
          expect { subject }.to raise_exception(expected_error, expected_error_message)
        end
      end

      context 'and given acr is within accepted acr values list' do
        let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }

        it_behaves_like 'properly encoded state payload jwt'
      end

      context 'and given type is not within accepted type values list' do
        let(:type) { 'some-arbitrary-type' }
        let(:expected_error) { SignIn::Errors::StatePayloadError }
        let(:expected_error_message) { 'Attributes are not valid' }

        it 'raises a code challenge state map error' do
          expect { subject }.to raise_exception(expected_error, expected_error_message)
        end
      end

      context 'and given type is within accepted type values list' do
        let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }

        it_behaves_like 'properly encoded state payload jwt'
      end

      context 'and given client_state is nil' do
        let(:client_state) { nil }

        it_behaves_like 'properly encoded state payload jwt'
      end

      context 'and given client_state is less than minimum client state length' do
        let(:client_state) { SecureRandom.alphanumeric(client_state_minimum_length - 1) }
        let(:expected_error) { SignIn::Errors::StatePayloadError }
        let(:expected_error_message) { 'Attributes are not valid' }

        it 'raises a code challenge state map error' do
          expect { subject }.to raise_exception(expected_error, expected_error_message)
        end
      end

      context 'and given client_state is greater than minimum client state length' do
        let(:client_state) { SecureRandom.alphanumeric(client_state_minimum_length + 1) }

        it_behaves_like 'properly encoded state payload jwt'
      end
    end

    context 'when client configuration is configured for pkce authentication' do
      let(:pkce) { true }

      context 'when code_challenge_method does not equal accepted method' do
        let(:code_challenge_method) { 'some-arbitrary-code-challenge-method' }
        let(:expected_error) { SignIn::Errors::CodeChallengeMethodMismatchError }
        let(:expected_error_message) { 'Code Challenge Method is not valid' }

        it 'raises a code challenge method mismatch error' do
          expect { subject }.to raise_exception(expected_error, expected_error_message)
        end
      end

      context 'when code_challenge_method equals accepted method' do
        let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }

        context 'and code_challenge is not present' do
          let(:code_challenge) { nil }
          let(:expected_error) { SignIn::Errors::CodeChallengeMalformedError }
          let(:expected_error_message) { 'Code Challenge is not valid' }

          it 'raises a code challenge method mismatch error' do
            expect { subject }.to raise_exception(expected_error, expected_error_message)
          end
        end

        context 'and code_challenge is not properly URL encoded' do
          let(:code_challenge) { '///some-not-url-safe code-challenge///' }
          let(:expected_error) { SignIn::Errors::CodeChallengeMalformedError }
          let(:expected_error_message) { 'Code Challenge is not valid' }

          it 'raises a code challenge method mismatch error' do
            expect { subject }.to raise_exception(expected_error, expected_error_message)
          end
        end

        context 'and code_challenge is properly URL encoded' do
          let(:code_challenge) { Base64.urlsafe_encode64('some-safe-code-challenge') }

          it_behaves_like 'validated code challenge state payload jwt'
        end
      end
    end

    context 'when client configuration is not configured for pkce authentication' do
      let(:pkce) { false }
      let(:code_challenge) { nil }

      it_behaves_like 'validated code challenge state payload jwt'
    end
  end
end
