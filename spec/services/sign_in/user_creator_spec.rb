# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserCreator do
  describe '#perform' do
    subject { SignIn::UserCreator.new(user_attributes: user_attributes, state: state).perform }

    let(:user_attributes) { { some_user_attribute: 'some-user-attribute' } }
    let(:state) { 'some-state' }

    context 'when state does not match a code challenge state map object' do
      let(:state) { 'some-arbitrary-state' }
      let(:expected_error) { SignIn::Errors::StateMismatchError }

      it 'raises a state mismatch error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when state matches a code challenge state map object' do
      let!(:code_challenge_state_map) { create(:code_challenge_state_map, state: state) }
      let(:state) { 'some-state' }

      context 'and user_attributes matches normalized attributes from a logingov service' do
        let(:user_attributes) do
          {
            uuid: csp_id,
            logingov_uuid: csp_id,
            loa: { current: LOA::THREE, highest: LOA::THREE },
            ssn: ssn,
            birth_date: birth_date,
            first_name: first_name,
            last_name: last_name,
            email: email,
            sign_in: { service_name: service_name }
          }
        end
        let(:state) { 'some-state' }
        let(:verified_at) { Time.zone.now }
        let(:csp_id) { SecureRandom.hex }
        let(:ssn) { '123456780' }
        let(:birth_date) { '2022-01-01' }
        let(:first_name) { 'some-first-name' }
        let(:last_name) { 'some-last-name' }
        let(:email) { 'some-email' }
        let(:service_name) { SAML::User::LOGINGOV_CSID }
        let!(:user_verification) { create(:logingov_user_verification, logingov_uuid: csp_id) }
        let(:login_code) { 'some-login-code' }

        before do
          allow(SecureRandom).to receive(:uuid).and_return(login_code)
        end

        it 'creates a user with expected attributes' do
          subject
          user = User.find(user_verification.user_account.id)
          expect(user.ssn).to eq(ssn)
          expect(user.logingov_uuid).to eq(csp_id)
          expect(user.birth_date).to eq(birth_date)
          expect(user.first_name).to eq(first_name)
          expect(user.last_name).to eq(last_name)
          expect(user.email).to eq(email)
        end

        it 'returns a login code' do
          expect(subject).to eq(login_code)
        end

        it 'creates a code container mapped to expected login code' do
          code = subject
          code_container = SignIn::CodeContainer.find(code)
          expect(code_container.user_account_uuid).to eq(user_verification.user_account.id)
          expect(code_container.code_challenge).to eq(code_challenge_state_map.code_challenge)
        end
      end

      context 'and user_attributes matches normalized attributes from an idme service' do
        let(:user_attributes) do
          {
            uuid: csp_id,
            idme_uuid: csp_id,
            loa: { current: LOA::THREE, highest: LOA::THREE },
            ssn: ssn,
            birth_date: birth_date,
            first_name: first_name,
            last_name: last_name,
            email: email,
            sign_in: { service_name: service_name }
          }
        end
        let(:state) { 'some-state' }
        let(:verified_at) { Time.zone.now }
        let(:csp_id) { SecureRandom.hex }
        let(:ssn) { '123456780' }
        let(:birth_date) { '2022-01-01' }
        let(:first_name) { 'some-first-name' }
        let(:last_name) { 'some-last-name' }
        let(:email) { 'some-email' }
        let(:service_name) { SAML::User::IDME_CSID }
        let!(:user_verification) { create(:idme_user_verification, idme_uuid: csp_id) }
        let(:login_code) { 'some-login-code' }

        before do
          allow(SecureRandom).to receive(:uuid).and_return(login_code)
        end

        it 'creates a user with expected attributes' do
          subject
          user = User.find(user_verification.user_account.id)
          expect(user.ssn).to eq(ssn)
          expect(user.idme_uuid).to eq(csp_id)
          expect(user.birth_date).to eq(birth_date)
          expect(user.first_name).to eq(first_name)
          expect(user.last_name).to eq(last_name)
          expect(user.email).to eq(email)
        end

        it 'returns a login code' do
          expect(subject).to eq(login_code)
        end

        it 'creates a code container mapped to expected login code' do
          code = subject
          code_container = SignIn::CodeContainer.find(code)
          expect(code_container.user_account_uuid).to eq(user_verification.user_account.id)
          expect(code_container.code_challenge).to eq(code_challenge_state_map.code_challenge)
        end
      end

      context 'and user_attributes is arbitrary' do
        let(:user_attributes) { { some_arbitrar_user_attribute: 'some-arbitrary-user-attribute' } }
        let(:expected_error) { SignIn::Errors::UserAttributesMalformedError }
        let(:expected_log_message) do
          "[SignIn::UserCreator] UserVerification not created, error=#{expected_error_message}"
        end
        let(:mocked_error) { StandardError }
        let(:expected_error_message) { mocked_error.new.message }

        before do
          allow_any_instance_of(Login::UserVerifier).to receive(:perform).and_raise(StandardError)
        end

        it 'logs a user verification not created message and raises user attributes malformed error' do
          expect(Rails.logger).to receive(:info).with(expected_log_message)
          expect { subject }.to raise_error(expected_error)
        end
      end
    end
  end
end
