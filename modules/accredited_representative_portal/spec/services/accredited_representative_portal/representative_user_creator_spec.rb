# frozen_string_literal: true

require 'rails_helper'
require 'timecop'

RSpec.describe AccreditedRepresentativePortal::RepresentativeUserCreator do
  describe '#perform' do
    subject(:representative_user_creator) do
      described_class.new(user_attributes:, state_payload:, verified_icn:, request_ip:)
    end

    let(:user_attributes) do
      {
        logingov_uuid:,
        loa:,
        csp_email:,
        current_ial:,
        max_ial:,
        multifactor:,
        authn_context:,
        first_name:,
        last_name:
      }
    end

    let(:state_payload) do
      create(:state_payload,
             client_state:,
             client_id:,
             code_challenge:,
             type:)
    end

    let(:logingov_uuid) { SecureRandom.hex }
    let(:authn_context) { service_name }
    let(:csp_email) { 'some-csp-email' }
    let(:first_name) { 'Jane' }
    let(:last_name) { 'Doe' }
    let(:request_ip) { '127.0.0.1' }
    let(:loa) { { current: SignIn::Constants::Auth::LOA_THREE, highest: SignIn::Constants::Auth::LOA_THREE } }
    let(:current_ial) { SignIn::Constants::Auth::IAL_TWO }
    let(:max_ial) { SignIn::Constants::Auth::IAL_TWO }
    let(:multifactor) { true }
    let(:service_name) { SignIn::Constants::Auth::LOGINGOV }
    let(:verified_icn) { 'verified-icn' }
    let!(:user_verification) { create(:logingov_user_verification, logingov_uuid:) }
    let(:user_uuid) { user_verification.backing_credential_identifier }
    let(:login_code) { 'some-login-code' }
    let(:expected_last_signed_in) { '2023-1-1' }
    let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
    let(:client_config) { create(:client_config) }
    let(:client_id) { client_config.client_id }
    let(:code_challenge) { 'some-code-challenge' }
    let(:type) { SignIn::Constants::Auth::LOGINGOV }
    let(:sign_in) do
      {
        service_name:,
        auth_broker: SignIn::Constants::Auth::BROKER_CODE,
        client_id:
      }
    end

    before do
      allow(SecureRandom).to receive(:uuid).and_return(login_code)
      Timecop.freeze(expected_last_signed_in)
    end

    after do
      Timecop.return
    end

    it 'creates a RepresentativeUser with expected attributes' do
      representative_user_creator.perform

      representative_user = AccreditedRepresentativePortal::RepresentativeUser.find(user_uuid)
      expect(representative_user).to be_a(AccreditedRepresentativePortal::RepresentativeUser)
      expect(representative_user.uuid).to eq(user_uuid)
      expect(representative_user.icn).to eq(verified_icn)
      expect(representative_user.email).to eq(csp_email)
      expect(representative_user.idme_uuid).to eq(nil)
      expect(representative_user.logingov_uuid).to eq(logingov_uuid)
      expect(representative_user.first_name).to eq(first_name)
      expect(representative_user.last_name).to eq(last_name)
      expect(representative_user.fingerprint).to eq(request_ip)
      expect(representative_user.last_signed_in).to eq(expected_last_signed_in)
      expect(representative_user.authn_context).to eq(authn_context)
      expect(representative_user.loa).to eq(loa)
      expect(representative_user.sign_in).to eq(sign_in)
    end

    it 'sets terms code to nil' do
      user_code_map = representative_user_creator.perform

      expect(user_code_map.terms_code).to be_nil
    end
  end
end
