# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::StatePayloadJwtEncoder do
  describe '#perform' do
    subject do
      SignIn::StatePayloadJwtEncoder.new(code_challenge: code_challenge,
                                         code_challenge_method: code_challenge_method,
                                         client_state: client_state,
                                         type: type,
                                         acr: acr,
                                         client_id: client_id).perform
    end

    let(:code_challenge) { 'some-code-challenge' }
    let(:code_challenge_method) { 'some-code-challenge-method' }
    let(:client_state) { 'some-client-state' }
    let(:acr) { 'some-acr' }
    let(:type) { 'some-type' }
    let(:client_id) { 'some-client-id' }
    let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }

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
        let(:code_challenge_remove_base64_padding) do
          Base64.urlsafe_encode64(Base64.urlsafe_decode64(code_challenge.to_s), padding: false)
        end
        let(:code) { 'some-state-code-value' }
        let(:client_id) { client_config.client_id }
        let(:client_config) { create(:client_config) }
        let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
        let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
        let(:client_state) { SecureRandom.alphanumeric(client_state_minimum_length + 1) }

        before do
          allow(SecureRandom).to receive(:hex).and_return(code)
        end

        shared_context 'properly encoded state payload jwt' do
          it 'returns an encoded jwt value' do
            decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
            expect(decoded_jwt.acr).to eq(acr)
            expect(decoded_jwt.type).to eq(type)
            expect(decoded_jwt.client_id).to eq(client_id)
            expect(decoded_jwt.code_challenge).to eq(code_challenge)
            expect(decoded_jwt.client_state).to eq(client_state)
            expect(decoded_jwt.code).to eq(code)
          end

          it 'saves a StateCode in redis' do
            expect { subject }.to change { SignIn::StateCode.find(code) }.from(nil)
          end
        end

        context 'and given client_id does not map to a configured client' do
          let(:client_id) { 'some-arbitrary-client-id' }
          let(:expected_error) { SignIn::Errors::StatePayloadError }
          let(:expected_error_message) { 'Attributes are not valid' }

          it 'raises a code challenge state map error' do
            expect { subject }.to raise_exception(expected_error, expected_error_message)
          end
        end

        context 'and given client_id maps to a configured client' do
          let(:client_id) { client_config.client_id }

          it_behaves_like 'properly encoded state payload jwt'
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
    end
  end
end
