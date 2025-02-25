# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::TokenParamsValidator, type: :model do
  subject(:validator) { described_class.new(params:) }

  describe '#perform' do
    shared_examples 'invalid params' do
      it { is_expected.not_to be_valid }

      it 'raises a MalformedParamsError' do
        expect { validator.perform }.to raise_error(SignIn::Errors::MalformedParamsError)
          .with_message(/#{expected_error_message}/)
      end
    end

    shared_examples 'valid params' do
      it 'is valid with all required attributes' do
        expect(validator).to be_valid
        expect(validator.perform).to be(true)
      end
    end

    let(:params) do
      {
        grant_type:,
        code:,
        code_verifier:,
        client_assertion:,
        client_assertion_type:,
        assertion:,
        subject_token:,
        subject_token_type:,
        actor_token:,
        actor_token_type:,
        client_id:
      }.compact
    end

    let(:grant_type) { nil }
    let(:code) { nil }
    let(:code_verifier) { nil }
    let(:client_assertion) { nil }
    let(:client_assertion_type) { nil }
    let(:assertion) { nil }
    let(:subject_token) { nil }
    let(:subject_token_type) { nil }
    let(:actor_token) { nil }
    let(:actor_token_type) { nil }
    let(:client_id) { nil }

    context 'when grant_type is AUTH_CODE_GRANT' do
      let(:grant_type) { SignIn::Constants::Auth::AUTH_CODE_GRANT }
      let(:code) { 'some-code' }
      let(:code_verifier) { 'some-code-verifier' }

      context 'when client_assertion_type is nil' do
        let(:client_assertion_type) { nil }

        it_behaves_like 'valid params'

        context 'when code is missing' do
          let(:code) { nil }
          let(:expected_error_message) { "Code can't be blank" }

          it_behaves_like 'invalid params'
        end

        context 'when code_verifier is missing' do
          let(:code_verifier) { nil }
          let(:expected_error_message) { "Code verifier can't be blank" }

          it_behaves_like 'invalid params'
        end
      end

      context 'when client_assertion_type is present' do
        let(:client_assertion_type) { 'some-client-assertion-type' }

        context 'when client_assertion_type is JWT_BEARER_CLIENT_AUTHENTICATION' do
          let(:client_assertion_type) { SignIn::Constants::Urn::JWT_BEARER_CLIENT_AUTHENTICATION }

          context 'when client_assertion is present' do
            let(:client_assertion) { 'some-client-assertion' }

            it_behaves_like 'valid params'

            context 'when code is missing' do
              let(:code) { nil }
              let(:expected_error_message) { "Code can't be blank" }

              it_behaves_like 'invalid params'
            end

            context 'when code_verifier is missing' do
              let(:code_verifier) { nil }

              it_behaves_like 'valid params'
            end
          end

          context 'when client_assertion is missing' do
            let(:client_assertion) { nil }
            let(:expected_error_message) { "Client assertion can't be blank" }

            it_behaves_like 'invalid params'
          end
        end

        context 'when client_assertion_type is not JWT_BEARER_CLIENT_AUTHENTICATION' do
          let(:client_assertion_type) { 'invalid-client-assertion-type' }
          let(:expected_error_message) { 'Client assertion type is not valid' }

          it_behaves_like 'invalid params'
        end
      end
    end

    context 'when grant_type is JWT_BEARER_GRANT' do
      let(:grant_type) { SignIn::Constants::Auth::JWT_BEARER_GRANT }

      context 'when assertion is present' do
        let(:assertion) { 'some-assertion' }

        it_behaves_like 'valid params'

        context 'when assertion is missing' do
          let(:assertion) { nil }
          let(:expected_error_message) { "Assertion can't be blank" }

          it_behaves_like 'invalid params'
        end
      end
    end

    context 'when grant_type is TOKEN_EXCHANGE_GRANT' do
      let(:grant_type) { SignIn::Constants::Auth::TOKEN_EXCHANGE_GRANT }
      let(:params) do
        {
          grant_type:,
          subject_token:,
          subject_token_type:,
          actor_token:,
          actor_token_type:,
          client_id:
        }.compact
      end

      let(:subject_token) { 'some-subject-token' }
      let(:subject_token_type) { 'some-subject-token-type' }
      let(:actor_token) { 'some-actor_token' }
      let(:actor_token_type) { 'some-actor-token-type' }
      let(:client_id) { 'some-client-id' }

      context 'when subject_token is missing' do
        let(:subject_token) { nil }
        let(:expected_error_message) { "Subject token can't be blank" }

        it_behaves_like 'invalid params'
      end

      context 'when subject_token_type is missing' do
        let(:subject_token_type) { nil }
        let(:expected_error_message) { "Subject token type can't be blank" }

        it_behaves_like 'invalid params'
      end

      context 'when actor_token is missing' do
        let(:actor_token) { nil }
        let(:expected_error_message) { "Actor token can't be blank" }

        it_behaves_like 'invalid params'
      end

      context 'when actor_token_type is missing' do
        let(:actor_token_type) { nil }
        let(:expected_error_message) { "Actor token type can't be blank" }

        it_behaves_like 'invalid params'
      end

      context 'when client_id is missing' do
        let(:client_id) { nil }
        let(:expected_error_message) { "Client can't be blank" }

        it_behaves_like 'invalid params'
      end

      context 'when all required attributes are present' do
        it_behaves_like 'valid params'
      end
    end

    context 'when grant_type is not valid' do
      let(:grant_type) { 'invalid_grant_type' }
      let(:expected_error_message) { 'Grant type is not valid' }

      it_behaves_like 'invalid params'
    end
  end
end
