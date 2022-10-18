# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserCreator do
  describe '#perform' do
    subject do
      SignIn::UserCreator.new(user_attributes: user_attributes, state_payload: state_payload, verified_icn: icn).perform
    end

    let(:user_attributes) do
      {
        uuid: csp_id,
        logingov_uuid: csp_id,
        loa: loa,
        csp_email: csp_email,
        sign_in: sign_in,
        multifactor: multifactor,
        authn_context: authn_context
      }
    end
    let(:state_payload) do
      create(:state_payload,
             client_state: client_state,
             client_id: client_id,
             code_challenge: code_challenge,
             type: type)
    end
    let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
    let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }
    let(:code_challenge) { 'some-code-challenge' }
    let(:type) { SignIn::Constants::Auth::REDIRECT_URLS.first }
    let(:csp_id) { SecureRandom.hex }
    let(:icn) { 'some-icn' }
    let(:loa) { { current: LOA::THREE, highest: LOA::THREE } }
    let(:csp_email) { 'some-csp-email' }
    let(:service_name) { SAML::User::LOGINGOV_CSID }
    let!(:user_verification) { create(:logingov_user_verification, logingov_uuid: csp_id) }
    let(:user_uuid) { user_verification.backing_credential_identifier }
    let(:multifactor) { true }
    let(:sign_in) { { service_name: service_name } }
    let(:authn_context) { service_name }
    let(:login_code) { 'some-login-code' }
    let(:expected_last_signed_in) { Time.zone.now }

    before do
      allow(SecureRandom).to receive(:uuid).and_return(login_code)
      Timecop.freeze
    end

    after { Timecop.return }

    it 'creates a user with expected attributes' do
      subject
      user = User.find(user_uuid)
      expect(user.logingov_uuid).to eq(csp_id)
      expect(user.last_signed_in).to eq(expected_last_signed_in)
      expect(user.loa).to eq(loa)
      expect(user.icn).to eq(icn)
      expect(user.email).to eq(csp_email)
      expect(user.identity_sign_in).to eq(sign_in)
      expect(user.authn_context).to eq(authn_context)
      expect(user.multifactor).to eq(multifactor)
    end

    it 'returns a user code map with expected attributes' do
      user_code_map = subject
      expect(user_code_map.login_code).to eq(login_code)
      expect(user_code_map.type).to eq(type)
      expect(user_code_map.client_state).to eq(client_state)
      expect(user_code_map.client_id).to eq(client_id)
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
