# frozen_string_literal: true

RSpec.shared_context 'callback_state_jwt_setup' do
  let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
  let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }
  let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
  let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
  let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
  let(:operation) { SignIn::Constants::Auth::AUTHORIZE }

  let(:state_value) do
    SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                       code_challenge_method:,
                                       acr:,
                                       client_config:,
                                       type:,
                                       client_state:,
                                       operation:).perform
  end

  let(:uplevel_state_value) do
    SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                       code_challenge_method:,
                                       acr:,
                                       client_config:,
                                       type:,
                                       client_state:,
                                       operation:).perform
  end
end
