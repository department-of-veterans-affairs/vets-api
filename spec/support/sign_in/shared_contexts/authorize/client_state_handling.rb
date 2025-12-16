# frozen_string_literal: true

RSpec.shared_context 'authorize_client_state_handling' do
  let(:state) { 'some-state' }
  let(:statsd_auth_success) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS }
  let(:expected_log) { '[SignInService] [V0::SignInController] authorize' }
  let(:expected_logger_context) do
    {
      type: type[:type],
      client_id: client_id_value,
      acr: acr_value,
      operation: operation_value
    }
  end

  before { allow(JWT).to receive(:encode).and_return(state) }

  context 'and client_state is not given' do
    let(:client_state) { {} }

    context 'and scope is device_sso' do
      let(:scope) { { scope: SignIn::Constants::Auth::DEVICE_SSO } }

      context 'and client config is not set up to enable device_sso' do
        let(:shared_sessions) { false }
        let(:expected_error) { 'Scope is not valid for Client' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and client config is set up to enable device_sso' do
        let(:shared_sessions) { true }
        let(:authentication) { SignIn::Constants::Auth::API }

        it_behaves_like 'authorize_successful_response'
      end
    end

    context 'and scope is not given' do
      let(:scope) { {} }

      it_behaves_like 'authorize_successful_response'
    end
  end

  context 'and client_state is greater than minimum client state length' do
    let(:client_state) do
      { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH + 1) }
    end

    context 'and scope is device_sso' do
      let(:scope) { { scope: SignIn::Constants::Auth::DEVICE_SSO } }

      context 'and client config is not set up to enable device_sso' do
        let(:shared_sessions) { false }
        let(:expected_error) { 'Scope is not valid for Client' }

        it_behaves_like 'authorize_error_response'
      end

      context 'and client config is set up to enable device_sso' do
        let(:shared_sessions) { true }
        let(:authentication) { SignIn::Constants::Auth::API }

        it_behaves_like 'authorize_successful_response'
      end
    end

    context 'and scope is not given' do
      let(:scope) { {} }

      it_behaves_like 'authorize_successful_response'
    end
  end

  context 'and client_state is less than minimum client state length' do
    let(:client_state) do
      { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH - 1) }
    end
    let(:expected_error) { 'Attributes are not valid' }

    it_behaves_like 'authorize_error_response'
  end
end
