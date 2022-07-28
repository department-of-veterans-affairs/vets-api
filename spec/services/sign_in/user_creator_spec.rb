# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserCreator do
  describe '#perform' do
    subject { SignIn::UserCreator.new(user_attributes: user_attributes, state_payload: state_payload).perform }

    let(:user_attributes) { { some_user_attribute: 'some-user-attribute' } }
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

    context 'user_attributes matches normalized attributes from a credential service' do
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
          sign_in: sign_in,
          multifactor: multifactor,
          authn_context: authn_context
        }
      end
      let(:state) { 'some-state' }
      let(:verified_at) { Time.zone.now }
      let(:csp_id) { SecureRandom.hex }
      let(:ssn) { '123456780' }
      let(:birth_date) { '2022-01-01' }
      let(:birth_date_ssn) { birth_date }
      let(:first_name) { 'some-first-name' }
      let(:last_name) { 'some-last-name' }
      let(:csp_email) { 'some-csp-email' }
      let(:icn) { 'some-icn' }
      let(:service_name) { SAML::User::LOGINGOV_CSID }
      let!(:user_verification) { create(:logingov_user_verification, logingov_uuid: csp_id) }
      let(:user_uuid) { user_verification.credential_identifier }
      let(:login_code) { 'some-login-code' }
      let(:expected_return_object) { [login_code, client_state] }
      let(:id_theft_flag) { false }
      let(:deceased_date) { nil }
      let(:sign_in) { { service_name: service_name } }
      let(:authn_context) { service_name }
      let(:multifactor) { true }
      let(:edipis) { ['some-edipi'] }
      let(:edipi) { edipis.first }
      let(:mhv_iens) { ['some-mhv-ien'] }
      let(:mhv_ien) { mhv_iens.first }
      let(:participant_ids) { ['some-participant-id'] }
      let(:participant_id) { participant_ids.first }
      let(:birls_ids) { ['some-birls-id'] }
      let(:birls_id) { participant_ids.first }

      before do
        allow(SecureRandom).to receive(:uuid).and_return(login_code)
        stub_mpi(build(:mvi_profile,
                       id_theft_flag: id_theft_flag,
                       deceased_date: deceased_date,
                       ssn: ssn,
                       icn: icn,
                       edipis: edipis,
                       edipi: edipi,
                       mhv_ien: mhv_ien,
                       mhv_iens: mhv_iens,
                       birls_id: birls_id,
                       birls_ids: birls_ids,
                       participant_id: participant_id,
                       participant_ids: participant_ids,
                       birth_date: birth_date_ssn,
                       given_names: [first_name],
                       family_name: last_name))
      end

      shared_context 'user creation blocked' do
        it 'raises a malformed mpi account error' do
          expect_any_instance_of(described_class).to receive(:log_message_to_sentry).with(expected_error_message,
                                                                                          'warn')

          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when current user id_theft_flag is detected as fradulent' do
        let(:id_theft_flag) { true }
        let(:expected_error) { SignIn::Errors::MPILockedAccountError }
        let(:expected_error_message) { 'Theft Flag Detected' }

        it_behaves_like 'user creation blocked'
      end

      context 'when current user is detected as deceased' do
        let(:deceased_date) { '2022-01-01' }
        let(:expected_error) { SignIn::Errors::MPILockedAccountError }
        let(:expected_error_message) { 'Death Flag Detected' }

        it_behaves_like 'user creation blocked'
      end

      context 'when mpi record for user has multiple edipis' do
        let(:edipis) { %w[some-edipi some-other-edipi] }
        let(:expected_error) { SignIn::Errors::MPIMalformedAccountError }
        let(:expected_error_message) { 'User attributes contain multiple distinct EDIPI values' }

        it_behaves_like 'user creation blocked'
      end

      context 'when mpi record for user has multiple mhv ids' do
        let(:mhv_iens) { %w[some-mhv-ien some-other-mhv-ien] }
        let(:expected_error) { SignIn::Errors::MPIMalformedAccountError }
        let(:expected_error_message) { 'User attributes contain multiple distinct MHV_ID values' }

        it_behaves_like 'user creation blocked'
      end

      context 'when mpi record for user has multiple participant ids' do
        let(:participant_ids) { %w[some-participant-id some-other-participant-id] }
        let(:expected_error) { SignIn::Errors::MPIMalformedAccountError }
        let(:expected_error_message) { 'User attributes contain multiple distinct CORP_ID values' }

        it_behaves_like 'user creation blocked'
      end

      context 'when mpi record for user has multiple birls ids' do
        let(:birls_ids) { %w[some-birls-id some-other-birls-id] }
        let(:expected_message) { 'User attributes contain multiple distinct BIRLS_ID values' }

        it 'logs a message to sentry' do
          expect_any_instance_of(described_class).to receive(:log_message_to_sentry).with(expected_message, 'warn')
          subject
        end
      end

      context 'when user verification cannot be created' do
        let(:expected_error) { SignIn::Errors::UserAttributesMalformedError }
        let(:expected_error_message) { 'User Attributes are Malformed' }

        before do
          allow_any_instance_of(Login::UserVerifier).to receive(:perform).and_return(nil)
        end

        it 'raises user attributes malformed error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when user verification can be properly created' do
        shared_context 'mpi user creation' do
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
            allow_any_instance_of(MPI::Service)
              .to receive(:add_person_implicit_search).and_return(add_person_response)
          end

          it 'makes an mpi call to create a new record' do
            expect_any_instance_of(MPI::Service).to receive(:add_person_implicit_search)
            subject
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

        context 'and current user does not have a retrievable icn' do
          before do
            stub_mpi_not_found
          end

          it_behaves_like 'mpi user creation'
        end

        context 'and current user does not have required attributes' do
          let(:birth_date_ssn) { nil }

          it_behaves_like 'mpi user creation'
        end

        it 'creates a user with expected attributes' do
          subject
          user = User.find(user_uuid)
          expect(user.ssn).to eq(ssn)
          expect(user.logingov_uuid).to eq(csp_id)
          expect(user.birth_date).to eq(birth_date)
          expect(user.first_name).to eq(first_name)
          expect(user.last_name).to eq(last_name)
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

        context 'when there is a mismatch with credential and mpi attributes' do
          let(:mpi_birth_date) { '1970-01-01' }
          let(:mpi_first_name) { 'some-mpi-first-name' }
          let(:mpi_last_name) { 'some-mpi-last-name' }
          let(:mpi_ssn) { '098765432' }

          before do
            stub_mpi(build(:mvi_profile,
                           id_theft_flag: id_theft_flag,
                           deceased_date: deceased_date,
                           ssn: mpi_ssn,
                           birth_date: mpi_birth_date,
                           given_names: [mpi_first_name],
                           family_name: mpi_last_name))
          end

          it 'prefers mpi attributes on the created user' do
            subject
            user = User.find(user_uuid)
            expect(user.ssn).to eq(mpi_ssn)
            expect(user.birth_date).to eq(mpi_birth_date)
            expect(user.first_name).to eq(mpi_first_name)
            expect(user.last_name).to eq(mpi_last_name)
          end
        end
      end
    end
  end
end
