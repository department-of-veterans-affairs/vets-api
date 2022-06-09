# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserCreator do
  describe '#perform' do
    subject { SignIn::UserCreator.new(user_attributes: user_attributes, state: state, type: type).perform }

    let(:user_attributes) { { some_user_attribute: 'some-user-attribute' } }
    let(:state) { 'some-state' }
    let(:type) { 'some-type' }

    context 'when state does not match a code challenge state map object' do
      let(:state) { 'some-arbitrary-state' }
      let(:expected_error) { SignIn::Errors::StateMismatchError }
      let(:expected_error_message) { 'Authentication Attempt Cannot be found' }

      it 'raises a state mismatch error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when state matches a code challenge state map object' do
      let!(:code_challenge_state_map) do
        create(:code_challenge_state_map,
               state: state,
               client_id: client_id,
               client_state: client_state)
      end
      let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
      let(:state) { 'some-state' }
      let(:client_id) { SignIn::Constants::Auth::CLIENT_IDS.first }

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
            csp_email: csp_email,
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
        let(:csp_email) { 'some-csp-email' }
        let(:service_name) { SAML::User::LOGINGOV_CSID }
        let!(:user_verification) { create(:logingov_user_verification, logingov_uuid: csp_id) }
        let(:login_code) { 'some-login-code' }
        let(:expected_return_object) { [login_code, client_state] }

        before do
          allow(SecureRandom).to receive(:uuid).and_return(login_code)
        end

        context 'and current user does not have a retrievable icn' do
          let(:add_person_response) do
            MPI::Responses::AddPersonResponse.new(status: status,
                                                  mvi_codes: mvi_codes,
                                                  error: error)
          end

          let(:status) { 'OK' }
          let(:mvi_codes) { { icn: icn } }
          let(:icn) { 'some-icn' }
          let(:error) { nil }

          before do
            stub_mpi_not_found
            allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(add_person_response)
          end

          it 'makes an mpi call to create a new record' do
            expect_any_instance_of(MPI::Service).to receive(:add_person_implicit_search)
            subject
          end

          context 'and the mpi add_person call is successful' do
            let(:status) { 'OK' }

            it 'saves the returned icn on the user model' do
              subject
              user = User.find(user_verification.user_account.id)
              expect(user.icn).to eq(icn)
            end
          end

          context 'and the mpi add_person call is not successful' do
            let(:status) { 'some-not-successful-status' }
            let(:expected_error) { SignIn::Errors::MPIUserCreationFailedError }
            let(:expected_error_message) { 'User MPI record cannot be created' }

            it 'raises an MPI user creation error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end
        end

        it 'creates a user with expected attributes' do
          subject
          user = User.find(user_verification.user_account.id)
          expect(user.ssn).to eq(ssn)
          expect(user.logingov_uuid).to eq(csp_id)
          expect(user.birth_date).to eq(birth_date)
          expect(user.first_name).to eq(first_name)
          expect(user.last_name).to eq(last_name)
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
          expect(code_container.code_challenge).to eq(code_challenge_state_map.code_challenge)
          expect(code_container.credential_email).to eq(csp_email)
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
            csp_email: csp_email,
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
        let(:csp_email) { 'some-csp-email' }
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
          expect(code_container.code_challenge).to eq(code_challenge_state_map.code_challenge)
          expect(code_container.credential_email).to eq(csp_email)
        end
      end

      context 'and user verification cannot be created' do
        let(:expected_error) { SignIn::Errors::UserAttributesMalformedError }
        let(:expected_error_message) { 'User Attributes are Malformed' }

        before do
          allow_any_instance_of(Login::UserVerifier).to receive(:perform).and_return(nil)
        end

        it 'logs a user verification not created message and raises user attributes malformed error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
