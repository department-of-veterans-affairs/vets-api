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
        expect(validator.perform).to eq(true)
      end
    end

    let(:params) do
      {
        grant_type:,
        code:,
        code_verifier:,
        client_assertion:,
        client_assertion_type:,
        assertion:
      }.compact
    end

    let(:grant_type) { nil }
    let(:code) { nil }
    let(:code_verifier) { nil }
    let(:client_assertion) { nil }
    let(:client_assertion_type) { nil }
    let(:assertion) { nil }

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

        context 'when client_assertion_type is CLIENT_ASSERTION_TYPE' do
          let(:client_assertion_type) { SignIn::Constants::Auth::CLIENT_ASSERTION_TYPE }

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

        context 'when client_assertion_type is not CLIENT_ASSERTION_TYPE' do
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

    context 'when grant_type is not valid' do
      let(:grant_type) { 'invalid_grant_type' }
      let(:expected_error_message) { 'Grant type is not valid' }

      it_behaves_like 'invalid params'
    end
  end
end
