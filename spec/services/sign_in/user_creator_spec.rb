# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserCreator do
  describe '#perform' do
    subject do
      SignIn::UserCreator.new(user_attributes:,
                              state_payload:,
                              verified_icn: icn,
                              request_ip:).perform
    end

    let(:user_attributes) do
      {
        logingov_uuid:,
        loa:,
        csp_email:,
        current_ial:,
        max_ial:,
        multifactor:,
        authn_context:
      }
    end
    let(:state_payload) do
      create(:state_payload,
             client_state:,
             client_id:,
             code_challenge:,
             type:)
    end
    let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
    let(:client_id) { client_config.client_id }
    let(:client_config) { create(:client_config) }
    let(:code_challenge) { 'some-code-challenge' }
    let(:type) { service_name }
    let(:current_ial) { SignIn::Constants::Auth::IAL_TWO }
    let(:max_ial) { SignIn::Constants::Auth::IAL_TWO }
    let(:logingov_uuid) { SecureRandom.hex }
    let(:icn) { 'some-icn' }
    let(:loa) { { current: SignIn::Constants::Auth::LOA_THREE, highest: SignIn::Constants::Auth::LOA_THREE } }
    let(:csp_email) { 'some-csp-email' }
    let(:service_name) { SignIn::Constants::Auth::LOGINGOV }
    let(:auth_broker) { SignIn::Constants::Auth::BROKER_CODE }
    let!(:user_verification) { create(:logingov_user_verification, logingov_uuid:) }
    let(:user_uuid) { user_verification.backing_credential_identifier }
    let(:multifactor) { true }
    let(:sign_in) { { service_name:, auth_broker:, client_id: } }
    let(:authn_context) { service_name }
    let(:login_code) { 'some-login-code' }
    let(:expected_last_signed_in) { '2023-1-1' }
    let(:expected_avc_at) { '2023-1-1' }
    let(:request_ip) { '123.456.78.90' }

    before do
      allow(SecureRandom).to receive(:uuid).and_return(login_code)
      Timecop.freeze(expected_last_signed_in)
    end

    after { Timecop.return }

    it 'creates a user with expected attributes' do
      subject
      user = User.find(user_uuid)
      expect(user.logingov_uuid).to eq(logingov_uuid)
      expect(user.last_signed_in).to eq(expected_last_signed_in)
      expect(user.loa).to eq(loa)
      expect(user.icn).to eq(icn)
      expect(user.email).to eq(csp_email)
      expect(user.identity_sign_in).to eq(sign_in)
      expect(user.authn_context).to eq(authn_context)
      expect(user.multifactor).to eq(multifactor)
      expect(user.fingerprint).to eq(request_ip)
    end

    it 'creates a user credential email with expected attributes' do
      expect { subject }.to change(UserCredentialEmail, :count)
      user = User.find(user_uuid)
      user_credential_email = user.user_verification.user_credential_email
      expect(user_credential_email.credential_email).to eq(csp_email)
    end

    it 'creates a user acceptable verified credential email with expected attributes' do
      expect { subject }.to change(UserAcceptableVerifiedCredential, :count)
      user = User.find(user_uuid)
      user_avc = UserAcceptableVerifiedCredential.find_by(user_account: user.user_account)
      expect(user_avc.acceptable_verified_credential_at).to eq(expected_avc_at)
    end

    it 'returns a user code map with expected attributes' do
      user_code_map = subject
      expect(user_code_map.login_code).to eq(login_code)
      expect(user_code_map.type).to eq(type)
      expect(user_code_map.client_state).to eq(client_state)
      expect(user_code_map.client_config).to eq(client_config)
    end

    it 'creates a code container mapped to expected login code' do
      user_code_map = subject
      code_container = SignIn::CodeContainer.find(user_code_map.login_code)
      expect(code_container.user_verification_id).to eq(user_verification.id)
      expect(code_container.code_challenge).to eq(code_challenge)
      expect(code_container.credential_email).to eq(csp_email)
      expect(code_container.client_id).to eq(client_id)
    end
  end
end
