# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AttributeValidator do
  describe '#perform' do
    subject { SignIn::AttributeValidator.new(user_attributes: user_attributes).perform }

    let(:user_attributes) { { current_ial: current_ial } }
    let(:current_ial) { SignIn::Constants::Auth::IAL_ONE }

    context 'when credential is not verified' do
      let(:current_ial) { SignIn::Constants::Auth::IAL_ONE }

      it 'returns nil' do
        expect(subject).to be nil
      end
    end

    context 'when credential is verified' do
      let(:user_attributes) do
        {
          logingov_uuid: logingov_uuid,
          idme_uuid: idme_uuid,
          current_ial: current_ial,
          ssn: ssn,
          birth_date: birth_date,
          first_name: first_name,
          last_name: last_name,
          csp_email: email,
          address: address,
          service_name: service_name,
          auto_uplevel: auto_uplevel,
          mhv_icn: mhv_icn,
          mhv_correlation_id: mhv_correlation_id,
          edipi: edipi
        }
      end
      let(:logingov_uuid) { nil }
      let(:idme_uuid) { nil }
      let(:mhv_correlation_id) { nil }
      let(:edipi) { nil }
      let(:current_ial) { SignIn::Constants::Auth::IAL_TWO }
      let(:ssn) { nil }
      let(:birth_date) { nil }
      let(:email) { nil }
      let(:first_name) { nil }
      let(:last_name) { nil }
      let(:address) do
        {
          street: street,
          street2: street2,
          postal_code: postal_code,
          state: state,
          city: city,
          country: country
        }
      end
      let(:street) { nil }
      let(:street2) { nil }
      let(:state) { nil }
      let(:postal_code) { nil }
      let(:city) { nil }
      let(:country) { nil }
      let(:mhv_icn) { nil }
      let(:auto_uplevel) { false }
      let(:add_person_response) { 'some-add-person-response' }
      let(:find_profile_response) { 'some-find-profile-response' }
      let(:update_profile_response) { 'some-update-profile-response' }

      before do
        allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(add_person_response)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile_response)
        allow_any_instance_of(MPI::Service).to receive(:update_profile).and_return(update_profile_response)
        allow(Rails.logger).to receive(:info)
      end

      shared_examples 'error response' do
        let(:expected_error_log) { 'attribute validator error' }
        it 'raises the expected error' do
          expect_any_instance_of(SignIn::Logger).to receive(:info)
            .with(expected_error_log,
                  { errors: expected_error_message,
                    credential_uuid: csp_id,
                    type: service_name })

          expect { subject }.to raise_error(expected_error, expected_error_message)
        end

        it 'adds the expected error code to the raised error' do
          subject
        rescue => e
          expect(e.code).to eq(expected_error_code)
        end
      end

      shared_examples 'mpi attribute validations' do
        context 'when current user id_theft_flag is detected as fradulent' do
          let(:id_theft_flag) { true }
          let(:expected_error) { SignIn::Errors::MPILockedAccountError }
          let(:expected_error_message) { 'Theft Flag Detected' }
          let(:expected_error_code) { SignIn::Constants::ErrorCode::MPI_LOCKED_ACCOUNT }

          it_behaves_like 'error response'
        end

        context 'when current user is detected as deceased' do
          let(:deceased_date) { '2022-01-01' }
          let(:expected_error) { SignIn::Errors::MPILockedAccountError }
          let(:expected_error_message) { 'Death Flag Detected' }
          let(:expected_error_code) { SignIn::Constants::ErrorCode::MPI_LOCKED_ACCOUNT }

          it_behaves_like 'error response'
        end

        context 'when mpi record for user has multiple edipis' do
          let(:edipis) { %w[some-edipi some-other-edipi] }
          let(:expected_error) { SignIn::Errors::MPIMalformedAccountError }
          let(:expected_error_message) { 'User attributes contain multiple distinct EDIPI values' }
          let(:expected_error_code) { SignIn::Constants::ErrorCode::MULTIPLE_EDIPI }

          it_behaves_like 'error response'
        end

        context 'when mpi record for user has multiple mhv ids' do
          let(:mhv_iens) { %w[some-mhv-ien some-other-mhv-ien] }
          let(:expected_error) { SignIn::Errors::MPIMalformedAccountError }
          let(:expected_error_message) { 'User attributes contain multiple distinct MHV_ID values' }
          let(:expected_error_code) { SignIn::Constants::ErrorCode::MULTIPLE_MHV_IEN }

          it_behaves_like 'error response'
        end

        context 'when mpi record for user has multiple participant ids' do
          let(:participant_ids) { %w[some-participant-id some-other-participant-id] }
          let(:expected_error) { SignIn::Errors::MPIMalformedAccountError }
          let(:expected_error_message) { 'User attributes contain multiple distinct CORP_ID values' }
          let(:expected_error_code) { SignIn::Constants::ErrorCode::MULTIPLE_CORP_ID }

          it_behaves_like 'error response'
        end
      end

      shared_examples 'mpi versus credential mismatch' do
        let(:mpi_birth_date) { birth_date }
        let(:mpi_first_name) { first_name }
        let(:mpi_last_name) { last_name }
        let(:mpi_ssn) { ssn }
        let(:mpi_profile) do
          build(:mvi_profile,
                id_theft_flag: id_theft_flag,
                deceased_date: deceased_date,
                ssn: mpi_ssn,
                icn: icn,
                edipis: edipis,
                edipi: edipis.first,
                mhv_ien: mhv_iens.first,
                mhv_iens: mhv_iens,
                birls_id: birls_ids.first,
                birls_ids: birls_ids,
                participant_id: participant_ids.first,
                participant_ids: participant_ids,
                birth_date: mpi_birth_date,
                given_names: [mpi_first_name],
                family_name: mpi_last_name)
        end

        before do
          stub_mpi(build(:mvi_profile,
                         id_theft_flag: id_theft_flag,
                         deceased_date: deceased_date,
                         ssn: mpi_ssn,
                         birth_date: mpi_birth_date,
                         given_names: [mpi_first_name],
                         family_name: mpi_last_name))
        end

        shared_examples 'attribute mismatch behavior' do
          let(:expected_error) { SignIn::Errors::AttributeMismatchError }
          let(:expected_error_message) { "Attribute mismatch, #{attribute} in credential does not match MPI attribute" }
          let(:expected_error_log) { 'attribute validator error' }
          let(:expected_params) do
            {
              last_name: last_name,
              ssn: ssn,
              birth_date: birth_date,
              icn: icn,
              email: email,
              address: address,
              idme_uuid: idme_uuid,
              logingov_uuid: logingov_uuid,
              edipi: edipi,
              first_name: first_name
            }
          end

          it 'makes a log to rails logger' do
            expect_any_instance_of(SignIn::Logger).to receive(:info).with(expected_error_log,
                                                                          { errors: expected_error_message,
                                                                            credential_uuid: csp_id,
                                                                            type: service_name })
            subject
          end

          it 'makes an mpi call to update correlation record' do
            expect_any_instance_of(MPI::Service).to receive(:update_profile).with(expected_params)
            subject
          end
        end

        context 'and attribute mismatch is first_name' do
          let(:mpi_first_name) { 'some-mpi-first-name' }
          let(:attribute) { 'first_name' }

          it_behaves_like 'attribute mismatch behavior'
        end

        context 'and attribute mismatch is last name' do
          let(:mpi_last_name) { 'some-mpi-last-name' }
          let(:attribute) { 'last_name' }

          it_behaves_like 'attribute mismatch behavior'
        end

        context 'and attribute mismatch is birth date' do
          let(:mpi_birth_date) { '1970-01-01' }
          let(:attribute) { 'birth_date' }

          it_behaves_like 'attribute mismatch behavior'
        end

        context 'and attribute mismatch is ssn' do
          let(:mpi_ssn) { '098765432' }
          let(:expected_error) { SignIn::Errors::AttributeMismatchError }
          let(:expected_error_message) { 'Attribute mismatch, ssn in credential does not match MPI attribute' }
          let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }
          let(:expected_error_context) do
            { csp_uuid: csp_id,
              icn: icn,
              type: user_attributes[:sign_in][:service_name] }
          end

          it_behaves_like 'error response'
        end
      end

      shared_examples 'missing credential attribute' do
        let(:expected_error) { SignIn::Errors::CredentialMissingAttributeError }
        let(:expected_error_message) { "Missing attribute in credential: #{attribute}" }
        let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

        it_behaves_like 'error response'
      end

      shared_examples 'credential mpi verification' do
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
        let(:mpi_profile) do
          build(:mvi_profile,
                id_theft_flag: id_theft_flag,
                deceased_date: deceased_date,
                ssn: ssn,
                icn: icn,
                edipis: edipis,
                edipi: edipis.first,
                mhv_ien: mhv_iens.first,
                mhv_iens: mhv_iens,
                birls_id: birls_ids.first,
                birls_ids: birls_ids,
                participant_id: participant_ids.first,
                participant_ids: participant_ids,
                birth_date: birth_date,
                given_names: [first_name],
                family_name: last_name)
        end
        let(:id_theft_flag) { false }
        let(:deceased_date) { nil }
        let(:icn) { 'some-icn' }
        let(:edipis) { ['some-edipi'] }
        let(:mhv_iens) { ['some-mhv-ien'] }
        let(:participant_ids) { ['some-participant-id'] }
        let(:birls_ids) { ['some-birls-id'] }

        context 'and mpi record exists for user' do
          it_behaves_like 'mpi attribute validations'

          context 'and auto_uplevel is set' do
            let(:auto_uplevel) { true }

            it 'does not make an mpi call to update correlation record' do
              expect_any_instance_of(MPI::Service).not_to receive(:update_profile)
              subject
            end
          end

          context 'and auto_uplevel is not set' do
            let(:auto_uplevel) { false }
            let(:update_profile_response) do
              create(:add_person_response, status: update_status, parsed_codes: { logingov_uuid: logingov_uuid })
            end
            let(:update_status) { :ok }

            it_behaves_like 'mpi versus credential mismatch'

            it 'makes an mpi call to update correlation record' do
              expect_any_instance_of(MPI::Service).to receive(:update_profile)
              subject
            end
          end
        end

        context 'and mpi record does not exist for user' do
          let(:add_person_response) { create(:add_person_response, status: status, parsed_codes: parsed_codes) }
          let(:status) { :ok }
          let(:icn) { 'some-icn' }
          let(:parsed_codes) { { icn: icn } }
          let(:expected_params) do
            {
              first_name: first_name,
              last_name: last_name,
              ssn: ssn,
              birth_date: birth_date,
              email: email,
              address: address,
              idme_uuid: idme_uuid,
              logingov_uuid: logingov_uuid
            }
          end

          before { allow_any_instance_of(SignIn::AttributeValidator).to receive(:mpi_record_exists?).and_return(false) }

          it_behaves_like 'mpi attribute validations'

          it 'makes an mpi call to create a new record' do
            expect_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).with(expected_params)

            subject
          end

          context 'and mpi add person call is not successful' do
            let(:status) { :server_error }
            let(:expected_error) { SignIn::Errors::MPIUserCreationFailedError }
            let(:expected_error_message) { 'User MPI record cannot be created' }
            let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

            it_behaves_like 'error response'
          end

          context 'and mpi add person call is successful' do
            let(:status) { :ok }

            it_behaves_like 'mpi attribute validations'
          end
        end
      end

      context 'and authentication is with mhv' do
        let(:service_name) { SignIn::Constants::Auth::MHV }
        let(:mhv_icn) { 'some-icn' }
        let(:idme_uuid) { 'some-idme-uuid' }
        let(:csp_id) { idme_uuid }
        let(:address) { nil }
        let(:mhv_correlation_id) { 'some-mhv-correlation-id' }
        let(:email) { 'some-email' }

        context 'and credential is missing mhv icn' do
          let(:mhv_icn) { nil }
          let(:attribute) { 'icn' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing mhv correlation id' do
          let(:mhv_correlation_id) { nil }
          let(:attribute) { 'mhv_uuid' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing idme uuid' do
          let(:idme_uuid) { nil }
          let(:attribute) { 'uuid' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing email' do
          let(:email) { nil }
          let(:attribute) { 'email' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is not missing any required attributes' do
          context 'and mpi record does not exist for user' do
            let(:find_profile_response) { nil }
            let(:expected_error) { SignIn::Errors::MHVMissingMPIRecordError }
            let(:expected_error_message) { 'No MPI Record for MHV Account' }
            let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

            it_behaves_like 'error response'
          end

          context 'and mpi record exists for user' do
            let(:add_person_response) { create(:add_person_response, status: status, parsed_codes: parsed_codes) }
            let(:status) { :ok }
            let(:icn) { mhv_icn }
            let(:parsed_codes) { { icn: icn } }
            let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
            let(:mpi_profile) do
              build(:mvi_profile,
                    id_theft_flag: id_theft_flag,
                    deceased_date: deceased_date,
                    ssn: ssn,
                    icn: icn,
                    edipis: edipis,
                    edipi: edipis.first,
                    mhv_ien: mhv_iens.first,
                    mhv_iens: mhv_iens,
                    birls_id: birls_ids.first,
                    birls_ids: birls_ids,
                    participant_id: participant_ids.first,
                    participant_ids: participant_ids,
                    birth_date: birth_date,
                    given_names: [first_name],
                    family_name: last_name)
            end
            let(:first_name) { 'some-first-name' }
            let(:last_name) { 'some-last-name' }
            let(:ssn) { 'some-ssn' }
            let(:birth_date) { '19700101' }
            let(:id_theft_flag) { false }
            let(:deceased_date) { nil }
            let(:edipis) { ['some-edipi'] }
            let(:mhv_iens) { ['some-mhv-ien'] }
            let(:participant_ids) { ['some-participant-id'] }
            let(:birls_ids) { ['some-birls-id'] }
            let(:expected_params) do
              {
                first_name: first_name,
                last_name: last_name,
                ssn: ssn,
                birth_date: birth_date,
                email: email,
                address: address,
                idme_uuid: idme_uuid,
                logingov_uuid: logingov_uuid
              }
            end

            it 'makes an mpi call to create a new record' do
              expect_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).with(expected_params)
              subject
            end

            context 'and mpi add person call is not successful' do
              let(:status) { :server_error }
              let(:expected_error) { SignIn::Errors::MPIUserCreationFailedError }
              let(:expected_error_message) { 'User MPI record cannot be created' }
              let(:expected_error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

              it_behaves_like 'error response'
            end

            context 'and mpi add person call is successful' do
              let(:status) { :ok }

              it_behaves_like 'mpi attribute validations'
            end
          end
        end
      end

      context 'and authentication is with logingov' do
        let(:service_name) { SignIn::Constants::Auth::LOGINGOV }
        let(:logingov_uuid) { 'some-logingov-uuid' }
        let(:csp_id) { logingov_uuid }
        let(:first_name) { 'some-first-name' }
        let(:last_name) { 'some-last-name' }
        let(:ssn) { '444444758' }
        let(:street) { 'some-street' }
        let(:street2) { 'some-street-2' }
        let(:postal_code) { 'some-postal-code' }
        let(:state) { 'some-state' }
        let(:city) { 'some-city' }
        let(:country) { 'USA' }
        let(:birth_date) { '1930-01-01' }
        let(:email) { 'some-email' }

        context 'and credential is missing email' do
          let(:email) { nil }
          let(:attribute) { 'email' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing logingov uuid' do
          let(:logingov_uuid) { nil }
          let(:attribute) { 'uuid' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing first_name' do
          let(:first_name) { nil }
          let(:attribute) { 'first_name' }

          context 'and credential has been auto-uplevelled' do
            let(:auto_uplevel) { true }
            let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
            let(:mpi_profile) do
              build(:mvi_profile,
                    id_theft_flag: id_theft_flag,
                    deceased_date: deceased_date,
                    ssn: ssn,
                    icn: icn,
                    edipis: edipis,
                    edipi: edipis.first,
                    mhv_ien: mhv_iens.first,
                    mhv_iens: mhv_iens,
                    birls_id: birls_ids.first,
                    birls_ids: birls_ids,
                    participant_id: participant_ids.first,
                    participant_ids: participant_ids,
                    birth_date: birth_date,
                    given_names: [first_name],
                    family_name: last_name)
            end
            let(:id_theft_flag) { false }
            let(:deceased_date) { nil }
            let(:icn) { 'some-icn' }
            let(:edipis) { ['some-edipi'] }
            let(:mhv_iens) { ['some-mhv-ien'] }
            let(:participant_ids) { ['some-participant-id'] }
            let(:birls_ids) { ['some-birls-id'] }

            it 'does not raise an error' do
              expect { subject }.not_to raise_error
            end
          end

          context 'and credential is a verified non-auto-uplevelled credential' do
            let(:auto_uplevel) { false }

            it_behaves_like 'missing credential attribute'
          end
        end

        context 'and credential is missing last_name' do
          let(:last_name) { nil }
          let(:attribute) { 'last_name' }

          context 'and credential has been auto-uplevelled' do
            let(:auto_uplevel) { true }
            let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
            let(:mpi_profile) do
              build(:mvi_profile,
                    id_theft_flag: id_theft_flag,
                    deceased_date: deceased_date,
                    ssn: ssn,
                    icn: icn,
                    edipis: edipis,
                    edipi: edipis.first,
                    mhv_ien: mhv_iens.first,
                    mhv_iens: mhv_iens,
                    birls_id: birls_ids.first,
                    birls_ids: birls_ids,
                    participant_id: participant_ids.first,
                    participant_ids: participant_ids,
                    birth_date: birth_date,
                    given_names: [first_name],
                    family_name: last_name)
            end
            let(:id_theft_flag) { false }
            let(:deceased_date) { nil }
            let(:icn) { 'some-icn' }
            let(:edipis) { ['some-edipi'] }
            let(:mhv_iens) { ['some-mhv-ien'] }
            let(:participant_ids) { ['some-participant-id'] }
            let(:birls_ids) { ['some-birls-id'] }

            it 'does not raise an error' do
              expect { subject }.not_to raise_error
            end
          end

          context 'and credential is a verified non-auto-uplevelled credential' do
            let(:auto_uplevel) { false }

            it_behaves_like 'missing credential attribute'
          end
        end

        context 'and credential is missing birth_date' do
          let(:birth_date) { nil }
          let(:attribute) { 'birth_date' }

          context 'and credential has been auto-uplevelled' do
            let(:auto_uplevel) { true }
            let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
            let(:mpi_profile) do
              build(:mvi_profile,
                    id_theft_flag: id_theft_flag,
                    deceased_date: deceased_date,
                    ssn: ssn,
                    icn: icn,
                    edipis: edipis,
                    edipi: edipis.first,
                    mhv_ien: mhv_iens.first,
                    mhv_iens: mhv_iens,
                    birls_id: birls_ids.first,
                    birls_ids: birls_ids,
                    participant_id: participant_ids.first,
                    participant_ids: participant_ids,
                    birth_date: birth_date,
                    given_names: [first_name],
                    family_name: last_name)
            end
            let(:id_theft_flag) { false }
            let(:deceased_date) { nil }
            let(:icn) { 'some-icn' }
            let(:edipis) { ['some-edipi'] }
            let(:mhv_iens) { ['some-mhv-ien'] }
            let(:participant_ids) { ['some-participant-id'] }
            let(:birls_ids) { ['some-birls-id'] }

            it 'does not raise an error' do
              expect { subject }.not_to raise_error
            end
          end

          context 'and credential is a verified non-auto-uplevelled credential' do
            let(:auto_uplevel) { false }

            it_behaves_like 'missing credential attribute'
          end
        end

        context 'and credential is missing ssn' do
          let(:ssn) { nil }
          let(:attribute) { 'ssn' }

          context 'and credential has been auto-uplevelled' do
            let(:auto_uplevel) { true }
            let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
            let(:mpi_profile) do
              build(:mvi_profile,
                    id_theft_flag: id_theft_flag,
                    deceased_date: deceased_date,
                    ssn: ssn,
                    icn: icn,
                    edipis: edipis,
                    edipi: edipis.first,
                    mhv_ien: mhv_iens.first,
                    mhv_iens: mhv_iens,
                    birls_id: birls_ids.first,
                    birls_ids: birls_ids,
                    participant_id: participant_ids.first,
                    participant_ids: participant_ids,
                    birth_date: birth_date,
                    given_names: [first_name],
                    family_name: last_name)
            end
            let(:id_theft_flag) { false }
            let(:deceased_date) { nil }
            let(:icn) { 'some-icn' }
            let(:edipis) { ['some-edipi'] }
            let(:mhv_iens) { ['some-mhv-ien'] }
            let(:participant_ids) { ['some-participant-id'] }
            let(:birls_ids) { ['some-birls-id'] }

            it 'does not raise an error' do
              expect { subject }.not_to raise_error
            end
          end

          context 'and credential is a verified non-auto-uplevelled credential' do
            let(:auto_uplevel) { false }

            it_behaves_like 'missing credential attribute'
          end
        end

        context 'and credential is not missing any required attributes' do
          it_behaves_like 'credential mpi verification'
        end
      end

      context 'and authentication is with dslogon' do
        let(:service_name) { SignIn::Constants::Auth::DSLOGON }
        let(:edipi) { 'some-edipi' }
        let(:idme_uuid) { 'some-idme-uuid' }
        let(:csp_id) { idme_uuid }
        let(:address) { nil }
        let(:first_name) { 'some-first-name' }
        let(:last_name) { 'some-last-name' }
        let(:ssn) { '444444758' }
        let(:birth_date) { '1930-01-01' }
        let(:email) { 'some-email' }

        context 'and credential is missing email' do
          let(:email) { nil }
          let(:attribute) { 'email' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing idme uuid' do
          let(:idme_uuid) { nil }
          let(:attribute) { 'uuid' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing edipi' do
          let(:edipi) { nil }
          let(:attribute) { 'dslogon_uuid' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing first_name' do
          let(:first_name) { nil }
          let(:attribute) { 'first_name' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing last_name' do
          let(:last_name) { nil }
          let(:attribute) { 'last_name' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing birth_date' do
          let(:birth_date) { nil }
          let(:attribute) { 'birth_date' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing ssn' do
          let(:ssn) { nil }
          let(:attribute) { 'ssn' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is not missing any required attributes' do
          it_behaves_like 'credential mpi verification'
        end
      end

      context 'and authentication is with idme' do
        let(:service_name) { SignIn::Constants::Auth::IDME }
        let(:idme_uuid) { 'some-idme-uuid' }
        let(:csp_id) { idme_uuid }
        let(:first_name) { 'some-first-name' }
        let(:last_name) { 'some-last-name' }
        let(:ssn) { '444444758' }
        let(:street) { 'some-street' }
        let(:street2) { nil }
        let(:state) { 'some-state' }
        let(:postal_code) { 'some-postal-code' }
        let(:city) { 'some-city' }
        let(:country) { 'USA' }
        let(:birth_date) { '1930-01-01' }
        let(:email) { 'some-email' }

        context 'and credential is missing email' do
          let(:email) { nil }
          let(:attribute) { 'email' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing idme uuid' do
          let(:idme_uuid) { nil }
          let(:attribute) { 'uuid' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing first_name' do
          let(:first_name) { nil }
          let(:attribute) { 'first_name' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing last_name' do
          let(:last_name) { nil }
          let(:attribute) { 'last_name' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing birth_date' do
          let(:birth_date) { nil }
          let(:attribute) { 'birth_date' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is missing ssn' do
          let(:ssn) { nil }
          let(:attribute) { 'ssn' }

          it_behaves_like 'missing credential attribute'
        end

        context 'and credential is not missing any required attributes' do
          it_behaves_like 'credential mpi verification'
        end
      end
    end
  end
end
