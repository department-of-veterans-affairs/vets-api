# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserCodeMapCreator do
  describe '#perform' do
    subject do
      described_class.new(user_attributes:,
                          state_payload:,
                          verified_icn: icn,
                          request_ip:).perform
    end

    let(:user_attributes) do
      {
        logingov_uuid:,
        csp_email:,
        all_csp_emails:,
        first_name:,
        last_name:
      }
    end
    let(:state_payload) do
      create(:state_payload,
             client_state:,
             client_id:,
             code_challenge:,
             type:,
             scope:)
    end
    let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
    let(:client_id) { client_config.client_id }
    let(:client_config) { create(:client_config, enforced_terms:) }
    let(:code_challenge) { 'some-code-challenge' }
    let(:type) { service_name }
    let(:logingov_uuid) { SecureRandom.hex }
    let(:icn) { 'some-icn' }
    let(:csp_email) { 'some-csp-email' }
    let(:all_csp_emails) { [csp_email] }
    let(:service_name) { SignIn::Constants::Auth::LOGINGOV }
    let(:auth_broker) { SignIn::Constants::Auth::BROKER_CODE }
    let!(:user_verification) { create(:logingov_user_verification, logingov_uuid:) }
    let(:user_uuid) { user_verification.backing_credential_identifier }
    let(:sign_in) { { service_name:, auth_broker:, client_id: } }
    let(:login_code) { 'some-login-code' }
    let(:expected_last_signed_in) { '2023-1-1' }
    let(:expected_avc_at) { '2023-1-1' }
    let(:request_ip) { '123.456.78.90' }
    let(:first_name) { Faker::Name.first_name }
    let(:last_name) { Faker::Name.last_name }
    let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }
    let(:device_sso) { true }
    let(:scope) { SignIn::Constants::Auth::DEVICE_SSO }
    let(:expected_user_attributes) { { first_name:, last_name:, email: csp_email, all_emails: all_csp_emails } }

    before do
      allow(SecureRandom).to receive(:uuid).and_return(login_code)
      Timecop.freeze(expected_last_signed_in)
    end

    after { Timecop.return }

    it 'creates a user credential email with expected attributes' do
      expect { subject }.to change(UserCredentialEmail, :count)
      user_credential_email = UserCredentialEmail.last
      expect(user_credential_email.credential_email).to eq(csp_email)
    end

    it 'creates a user acceptable verified credential email with expected attributes' do
      expect { subject }.to change(UserAcceptableVerifiedCredential, :count)
      user_acceptable_verified_credential = UserAcceptableVerifiedCredential.last
      expect(user_acceptable_verified_credential.acceptable_verified_credential_at).to eq(expected_avc_at)
    end

    it 'returns a user code map with expected attributes' do
      user_code_map = subject
      expect(user_code_map.login_code).to eq(login_code)
      expect(user_code_map.type).to eq(type)
      expect(user_code_map.client_state).to eq(client_state)
      expect(user_code_map.client_config).to eq(client_config)
    end

    context 'if client config enforced terms is set to va terms' do
      let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }
      let(:user_account_uuid) { user_verification.user_account.id }

      context 'and user needs accepted terms of use' do
        it 'sets terms_code on returned user code map' do
          expect(subject.terms_code).not_to be_nil
        end

        it 'creates a terms code container associated with terms code and with expected user attributes' do
          terms_code_container = SignIn::TermsCodeContainer.find(subject.terms_code)
          expect(terms_code_container.user_account_uuid).to eq(user_account_uuid)
        end
      end

      context 'and user does not need accepted terms of use' do
        let!(:accepted_terms_of_use) { create(:terms_of_use_agreement, user_account: user_verification.user_account) }

        it 'does not set terms_code on returned user code map' do
          expect(subject.terms_code).to be_nil
        end
      end
    end

    context 'if client config enforced terms is set to nil' do
      let(:enforced_terms) { nil }

      it 'does not set terms_code on returned user code map' do
        expect(subject.terms_code).to be_nil
      end
    end

    context 'if state payload scope is set to device sso' do
      let(:scope) { SignIn::Constants::Auth::DEVICE_SSO }
      let(:expected_device_sso) { true }

      it 'creates a code container with device_sso attribute set to false' do
        user_code_map = subject
        code_container = SignIn::CodeContainer.find(user_code_map.login_code)
        expect(code_container.device_sso).to eq(expected_device_sso)
      end
    end

    context 'if state payload scope is not set to device sso' do
      let(:scope) { 'some-scope' }
      let(:expected_device_sso) { false }

      it 'creates a code container with device_sso attribute set to false' do
        user_code_map = subject
        code_container = SignIn::CodeContainer.find(user_code_map.login_code)
        expect(code_container.device_sso).to eq(expected_device_sso)
      end
    end

    it 'creates a code container mapped to expected login code' do
      user_code_map = subject
      code_container = SignIn::CodeContainer.find(user_code_map.login_code)
      expect(code_container.user_verification_id).to eq(user_verification.id)
      expect(code_container.code_challenge).to eq(code_challenge)
      expect(code_container.credential_email).to eq(csp_email)
      expect(code_container.client_id).to eq(client_id)
      expect(code_container.user_attributes).to eq(expected_user_attributes)
      expect(code_container.device_sso).to eq(device_sso)
    end
  end
end
