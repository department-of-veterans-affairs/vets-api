# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'callback_setup'

  describe 'GET callback' do
    context 'when error is not given' do
      let(:error_params) { {} }

      context 'when code is not given' do
        let(:code) { {} }
        let(:expected_error) { 'Code is not defined' }
        let(:client_id) { nil }
        let(:operation) { nil }

        it_behaves_like 'callback_api_error_response'
      end

      context 'when state is not given' do
        let(:state) { {} }
        let(:expected_error) { 'State is not defined' }
        let(:client_id) { nil }
        let(:operation) { nil }

        it_behaves_like 'callback_api_error_response'
      end

      context 'when state is arbitrary' do
        let(:state_value) { 'some-state' }
        let(:expected_error) { 'State JWT is malformed' }
        let(:client_id) { nil }
        let(:operation) { nil }

        it_behaves_like 'callback_api_error_response'
      end

      context 'when state is a JWT but with improper signature' do
        let(:state_value) { JWT.encode('some-state', private_key, encode_algorithm) }
        let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:encode_algorithm) { SignIn::Constants::Auth::JWT_ENCODE_ALGORITHM }
        let(:expected_error) { 'State JWT body does not match signature' }
        let(:client_id) { nil }
        let(:operation) { nil }

        it_behaves_like 'callback_api_error_response'
      end

      context 'when state is a proper, expected JWT' do
        include_context 'callback_state_jwt_setup'

        context 'and code in state payload does not match an existing state code' do
          let(:expected_error) { 'Code in state is not valid' }
          let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }

          before { allow(SignIn::StateCode).to receive(:find).and_return(nil) }

          it_behaves_like 'callback_error_response'
        end
      end
    end

    context 'when error is given' do
      let(:error_params) { { error: error_value } }

      context 'and error is access denied value' do
        let(:error_value) { SignIn::Constants::Auth::ACCESS_DENIED }
        let(:expected_error) { 'User Declined to Authorize Client' }

        context 'and type from state is logingov' do
          include_context 'callback_state_jwt_setup'
          let(:type) { SignIn::Constants::Auth::LOGINGOV }
          let(:error_code) { SignIn::Constants::ErrorCode::LOGINGOV_VERIFICATION_DENIED }

          it_behaves_like 'callback_error_response'
        end

        context 'and type from state is some other value' do
          include_context 'callback_state_jwt_setup'
          let(:type) { SignIn::Constants::Auth::IDME }
          let(:error_code) { SignIn::Constants::ErrorCode::IDME_VERIFICATION_DENIED }

          it_behaves_like 'callback_error_response'
        end
      end

      context 'and error is an arbitrary value' do
        let(:error_value) { 'some-error-value' }
        let(:expected_error) { 'Unknown Credential Provider Issue' }
        let(:error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

        include_context 'callback_state_jwt_setup'

        it_behaves_like 'callback_error_response'
      end
    end
  end
end
