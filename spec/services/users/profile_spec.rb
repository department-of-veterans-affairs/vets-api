# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Profile do
  let!(:user_verification) { create(:user_verification) }
  let(:user_account) { user_verification.user_account }
  let(:user) do
    build(:user, :accountable, user_account:, icn: user_account.icn, user_verification:,
                               idme_uuid: user_verification.idme_uuid)
  end
  let!(:in_progress_form_user_uuid) { create(:in_progress_form, user_uuid: user.uuid) }
  let!(:in_progress_form_user_account) { create(:in_progress_form, user_account:) }

  describe '.initialize' do
    let(:users_profile) { Users::Profile.new(user) }

    it 'sets #scaffold.status to 200' do
      expect(users_profile.scaffold.status).to eq 200
    end

    it 'sets #scaffold.errors to an empty array' do
      expect(users_profile.scaffold.errors).to eq []
    end

    context 'when initialized with a non-User object' do
      it 'raises an exception' do
        user_account = build(:user_account)

        expect { Users::Profile.new(user_account) }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end
  end

  describe '#pre_serialize' do
    subject { Users::Profile.new(user).pre_serialize }

    let(:edipi) { '1005127153' }
    let(:profile) { subject.profile }
    let(:va_profile) { subject.va_profile }
    let(:veteran_status) { subject.veteran_status }

    before do
      allow(user).to receive(:edipi).and_return(edipi)
    end

    it 'does not include ssn anywhere', :aggregate_failures do
      expect(subject.try(:ssn)).to be_nil
      expect(subject.profile['ssn']).to be_nil
      expect(subject.va_profile['ssn']).to be_nil
    end

    it 'sets the status to 200' do
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[method body],
                                                                                  allow_playback_repeats: true) do
        expect(subject.status).to eq 200
      end
    end

    it 'sets the errors to nil' do
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[method body],
                                                                                  allow_playback_repeats: true) do
        expect(subject.errors).to be_nil
      end
    end

    describe '#in_progress_forms' do
      let(:expected_forms_metadata) { [in_progress_form_user_uuid.metadata, in_progress_form_user_account.metadata] }
      let(:expected_forms_id) { [in_progress_form_user_uuid.form_id, in_progress_form_user_account.form_id] }
      let(:expected_forms_updated_at) do
        [in_progress_form_user_uuid.updated_at.to_i, in_progress_form_user_account.updated_at.to_i]
      end

      it 'includes form id' do
        expect(subject.in_progress_forms.map { |form| form[:form] }).to match_array(expected_forms_id)
      end

      it 'includes last updated' do
        expect(subject.in_progress_forms.map { |form| form[:lastUpdated] }).to match_array(expected_forms_updated_at)
      end

      it 'includes metadata' do
        expect(subject.in_progress_forms.map { |form| form[:metadata] }).to match_array(expected_forms_metadata)
      end
    end

    describe '#profile' do
      # --- positive tests ---
      context 'idme user' do
        it 'includes authn_context' do
          expect(profile[:authn_context]).to eq(LOA::IDME_LOA3_VETS)
        end

        it 'includes sign_in' do
          expect(profile[:sign_in]).to eq(service_name: SAML::User::IDME_CSID,
                                          auth_broker: SAML::URLService::BROKER_CODE,
                                          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first)
        end

        context 'multifactor' do
          let(:user) { create(:user, :loa1, authn_context: 'multifactor') }

          it 'includes authn_context' do
            expect(profile[:authn_context]).to eq('multifactor')
          end

          it 'includes sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq(SAML::User::IDME_CSID)
          end
        end
      end

      context 'mhv user' do
        let(:user) { create(:user, :mhv) }
        let!(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_credential_uuid) }

        it 'includes sign_in' do
          expect(profile[:sign_in]).to eq(service_name: SAML::User::MHV_ORIGINAL_CSID,
                                          auth_broker: SAML::URLService::BROKER_CODE,
                                          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first)
        end
      end

      describe 'form 526 required identifiers' do
        context 'when the user has the form_526_required_identifiers_in_user_object feature flag on' do
          before do
            Flipper.enable(:form_526_required_identifiers_in_user_object)
          end

          context 'when a user is missing an identifier required by the 526 form' do
            it 'has a value of false in the [:claims][:form526_required_identifier_presence] hash' do
              allow(user).to receive(:participant_id).and_return(nil)

              identifiers = profile[:claims][:form526_required_identifier_presence]
              expect(identifiers['participant_id']).to be(false)
            end
          end

          context 'when a user is not missing an identifier required by the 526 form' do
            it 'has a value of true in the [:claims][:form526_required_identifier_presence] hash' do
              allow(user).to receive(:participant_id).and_return('8675309')

              identifiers = profile[:claims][:form526_required_identifier_presence]
              expect(identifiers['participant_id']).to be(true)
            end
          end
        end

        context 'when the user has the form_526_required_identifiers_in_user_object feature flag off' do
          before do
            Flipper.disable(:form_526_required_identifiers_in_user_object)
          end

          it 'does not include the identifiers in the claims section of the user profile' do
            expect(profile[:claims][:form526_required_identifier_presence]).to be_nil
          end
        end
      end

      it 'includes initial_sign_in' do
        expect(profile[:initial_sign_in]).to eq(user.initial_sign_in)
      end

      it 'includes email' do
        expect(profile[:email]).to eq(user.email)
      end

      it 'includes first_name' do
        expect(profile[:first_name]).to eq(user.first_name)
      end

      it 'includes middle_name' do
        expect(profile[:middle_name]).to eq(user.middle_name)
      end

      it 'includes last_name' do
        expect(profile[:last_name]).to eq(user.last_name)
      end

      it 'includes preferred_name' do
        expect(profile[:preferred_name]).to eq(user.preferred_name)
      end

      it 'includes birth_date' do
        expect(profile[:birth_date]).to eq(user.birth_date)
      end

      it 'includes gender' do
        expect(profile[:gender]).to eq(user.gender)
      end

      it 'includes zip' do
        expect(profile[:zip]).to eq(user.postal_code)
      end

      it 'includes last_signed_in' do
        expect(profile[:last_signed_in].httpdate).to eq(user.last_signed_in.httpdate)
      end

      it 'includes icn' do
        expect(profile[:icn]).to eq(user.icn)
      end

      it 'includes birls_id' do
        expect(profile[:birls_id]).to eq(user.birls_id)
      end

      it 'includes edipi' do
        expect(profile[:edipi]).to eq(user.edipi)
      end

      it 'includes sec_id' do
        expect(profile[:sec_id]).to eq(user.sec_id)
      end

      it 'includes logingov_uuid' do
        expect(profile[:logingov_uuid]).to eq(user.logingov_uuid)
      end

      it 'includes idme_uuid' do
        expect(profile[:idme_uuid]).to eq(user.idme_uuid)
      end

      it 'includes id_theft_flag' do
        expect(profile[:id_theft_flag]).to eq(user.id_theft_flag)
      end

      # --- negative tests ---
      it 'does not include uuid in the profile' do
        expect(profile[:uuid]).to be_nil
      end

      it 'does not include participant_id in the profile' do
        expect(profile[:participant_id]).to be_nil
      end
    end

    describe '#va_profile' do
      context 'when mpi_profile is not nil' do
        it 'includes birth_date' do
          expect(va_profile[:birth_date]).to eq(user.birth_date_mpi)
        end

        it 'includes family_name' do
          expect(va_profile[:family_name]).to eq(user.last_name_mpi)
        end

        it 'includes gender' do
          expect(va_profile[:gender]).to eq(user.gender_mpi)
        end

        it 'includes given_names' do
          expect(va_profile[:given_names]).to eq(user.given_names)
        end

        it 'includes status' do
          expect(va_profile[:status]).to eq(Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok])
        end

        it 'sets the status to 200' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200',
                           match_requests_on: %i[method body], allow_playback_repeats: true) do
            expect(subject.status).to eq 200
          end
        end

        it 'includes cerner_id' do
          expect(va_profile[:cerner_id]).to eq(user.cerner_id)
        end

        it 'includes cerner_facility_ids' do
          expect(va_profile[:cerner_facility_ids]).to eq(user.cerner_facility_ids)
        end

        it 'includes active_mhv_ids' do
          expect(va_profile[:active_mhv_ids]).to eq(user.active_mhv_ids)
        end

        context 'Oracle Health facility checks' do
          before do
            allow(Settings.mhv.oh_facility_checks).to receive_messages(
              pretransitioned_oh_facilities: '612, 357, 555',
              facilities_ready_for_info_alert: '555, 500',
              oh_migrations_list: '2026-03-03:[321,Test VA],[654,Another VA],[777,Third VA]'
            )
          end

          context 'when user has pre-transitioned OH facility' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[612 999])
            end

            it 'sets user_at_pretransitioned_oh_facility to true' do
              expect(va_profile[:user_at_pretransitioned_oh_facility]).to be true
            end
          end

          context 'when user does not have pretransitioned OH facility' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[999 888])
            end

            it 'sets user_at_pretransitioned_oh_facility to false' do
              expect(va_profile[:user_at_pretransitioned_oh_facility]).to be false
            end
          end

          context 'when user has facility ready for info alert' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[555 999])
            end

            it 'sets user_facility_ready_for_info_alert to true' do
              expect(va_profile[:user_facility_ready_for_info_alert]).to be true
            end
          end

          context 'when user does not have facility ready for info alert' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[999 888])
            end

            it 'sets user_facility_ready_for_info_alert to false' do
              expect(va_profile[:user_facility_ready_for_info_alert]).to be false
            end
          end

          context 'when user has facility migrating to OH' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[321 999])
            end

            it 'sets user_facility_migrating_to_oh to true' do
              expect(va_profile[:oh_migration_info][:user_facility_migrating_to_oh]).to be true
            end
          end

          context 'when user does not have facility migrating to OH' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[999 888])
            end

            it 'sets user_facility_migrating_to_oh to false' do
              expect(va_profile[:oh_migration_info][:user_facility_migrating_to_oh]).to be false
            end
          end

          context 'when user has multiple facilities including migrating facility' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[654 999])
            end

            it 'sets user_facility_migrating_to_oh to true' do
              expect(va_profile[:oh_migration_info][:user_facility_migrating_to_oh]).to be true
            end
          end

          context 'when user has multiple facilities including OH facilities' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[612 555 321 999])
            end

            it 'correctly identifies all three flags' do
              expect(va_profile[:user_at_pretransitioned_oh_facility]).to be true
              expect(va_profile[:user_facility_ready_for_info_alert]).to be true
              expect(va_profile[:oh_migration_info][:user_facility_migrating_to_oh]).to be true
            end
          end

          context 'when user has no facilities' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return([])
            end

            it 'sets all flags to false' do
              expect(va_profile[:user_at_pretransitioned_oh_facility]).to be false
              expect(va_profile[:user_facility_ready_for_info_alert]).to be false
              expect(va_profile[:oh_migration_info][:user_facility_migrating_to_oh]).to be false
            end
          end

          context 'when user has facilities but none match OH facility lists' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[111 222 333])
            end

            it 'sets all OH facility flags to false' do
              expect(va_profile[:user_at_pretransitioned_oh_facility]).to be false
              expect(va_profile[:user_facility_ready_for_info_alert]).to be false
              expect(va_profile[:oh_migration_info][:user_facility_migrating_to_oh]).to be false
            end
          end

          context 'when user has migrating facility but not other OH facilities' do
            before do
              allow(user).to receive(:va_treatment_facility_ids).and_return(%w[777 111])
            end

            it 'only sets user_facility_migrating_to_oh to true' do
              expect(va_profile[:user_at_pretransitioned_oh_facility]).to be false
              expect(va_profile[:user_facility_ready_for_info_alert]).to be false
              expect(va_profile[:oh_migration_info][:user_facility_migrating_to_oh]).to be true
            end
          end
        end
      end

      context 'when mpi_profile is nil' do
        let(:user) { build(:user) }
        let(:ok_status) do
          Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok]
        end

        it 'returns va_profile as null' do
          expect(va_profile).to eq({ status: ok_status })
        end

        it 'does not populate the #errors array with the serialized error', :aggregate_failures do
          external_services_errors = subject.errors.map { |error| error[:external_service] }

          expect(external_services_errors).not_to include 'MVI'
        end

        it 'logs an error when user is not loa3' do
          profile_instance = Users::Profile.new(user)
          expect(Rails.logger).to receive(:warn) do |message, log_arg|
            expect(message).to eq('Users::Profile external service error')
            log_hash = JSON.parse(log_arg)
            expect(log_hash['error']['external_service']).to eq('MVI')
            expect(log_hash['error']['description']).to eq('User is not LOA3, MPI access denied')
            expect(log_hash['error']['method']).to eq('mpi_profile')
          end
          profile_instance.send(:mpi_profile)
        end
      end

      context 'when user.mpi_status is not found' do
        before { stub_mpi_not_found }

        it 'returns va_profile as null' do
          expect(va_profile).to be_nil
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          error = subject.errors.first
          expect(error[:external_service]).to eq 'MVI'
          expect(error[:start_time]).to be_present
          expect(error[:description]).to include 'Record not found'
          expect(error[:status]).to eq 404
        end

        it 'sets the status to 296' do
          expect(subject.status).to eq 296
        end
      end
    end

    describe '#veteran_status' do
      let(:veteran_status_with_nil) do
        {
          status: Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok],
          is_veteran: nil,
          served_in_military: nil
        }
      end

      context 'when a veteran status is successfully returned' do
        it 'includes is_veteran' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200',
                           match_requests_on: %i[method body], allow_playback_repeats: true) do
            expect(veteran_status[:is_veteran]).to eq(user.veteran?)
          end
        end

        it 'includes status' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200',
                           match_requests_on: %i[method body], allow_playback_repeats: true) do
            expect(veteran_status[:status]).to eq(Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok])
          end
        end

        it 'includes served_in_military' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200',
                           match_requests_on: %i[method body], allow_playback_repeats: true) do
            expect(veteran_status[:served_in_military]).to eq(user.served_in_military?)
          end
        end

        it 'sets the status to 200' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200',
                           match_requests_on: %i[method body], allow_playback_repeats: true) do
            expect(subject.status).to eq 200
          end
        end
      end

      context 'when a veteran status is not found' do
        it 'sets veteran_status to nil' do
          expect(veteran_status).to be_nil
        end

        it 'populates the #errors array with the serialized error' do
          VCR.use_cassette('va_profile/veteran_status/veteran_status_404_oid_blank',
                           match_requests_on: %i[method body], allow_playback_repeats: true) do
            error = subject.errors.first
            expect(error[:external_service]).to eq 'VAProfile'
            expect(error[:start_time]).to be_present
            expect(error[:description]).to be_present
            expect(error[:status]).to eq 404
          end
        end

        it 'sets the status to 296' do
          expect(subject.status).to eq 296
        end
      end

      context 'when a veteran status call returns an error' do
        it 'sets veteran_status to nil' do
          expect(veteran_status).to be_nil
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          error = subject.errors.first

          expect(error[:external_service]).to eq 'VAProfile'
          expect(error[:start_time]).to be_present
          expect(error[:description]).to be_present
          expect(error[:status]).to eq 503
        end

        it 'sets the status to 296' do
          expect(subject.status).to eq 296
        end
      end

      context 'when LOA1 user' do
        before do
          user.loa[:current] = 1
        end

        context 'with blank edipi' do
          let(:edipi) { nil }
          let(:expected_object) do
            { status: ok_status, is_veteran: nil, served_in_military: nil }
          end
          let(:ok_status) do
            Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok]
          end

          it 'returns nil for veteran_status' do
            expect(veteran_status).to eq(expected_object)
          end

          it 'logs skipping message' do
            expect(Rails.logger).to receive(:info).with(
              'Skipping VAProfile veteran status call, No EDIPI present',
              user_uuid: user.uuid,
              loa: user.loa
            )
            Users::Profile.new(user).send(:veteran_status)
          end

          it 'sets the status to 200 when edipi is blank' do
            expect(subject.status).to eq 200
          end
        end
      end

      context 'when a LOA3 user' do
        context 'with blank edipi' do
          let(:edipi) { nil }

          it 'returns object with nils for veteran_status when edipi is blank' do
            expect(veteran_status).to eq(veteran_status_with_nil)
          end

          it 'logs skipping message' do
            expect(Rails.logger).to receive(:info).with(
              'Skipping VAProfile veteran status call, No EDIPI present',
              user_uuid: user.uuid,
              loa: user.loa
            )
            Users::Profile.new(user).send(:veteran_status)
          end

          it 'sets the status to 200 when edipi is blank' do
            expect(subject.status).to eq 200
          end
        end
      end
    end

    describe '#vet360_contact_information' do
      context 'with an loa1 user' do
        let(:user) { build(:user, :loa1, vet360_id: nil, icn: nil) }

        it 'returns an empty hash', :aggregate_failures do
          expect(user.vet360_contact_info).to be_nil
          expect(subject.vet360_contact_information).to eq({})
        end
      end

      context 'with a valid user' do
        let(:user) { build(:user, :loa3) }
        let(:vet360_info) { subject.vet360_contact_information }

        it 'is populated', :aggregate_failures do
          expect(user.vet360_contact_info).not_to be_nil
          expect(vet360_info[:vet360_id]).to be_present
          expect(vet360_info[:email]).to be_present
          expect(vet360_info[:residential_address]).to be_present
          expect(vet360_info[:mailing_address]).to be_present
          expect(vet360_info[:home_phone]).to be_present
          expect(vet360_info[:mobile_phone]).to be_present
          expect(vet360_info[:work_phone]).to be_present
          expect(vet360_info[:fax_number]).to be_present
          expect(vet360_info[:temporary_phone]).to be_present
          expect(vet360_info).to have_key(:contact_email_verified)
          expect(vet360_info[:contact_email_verified]).to be_in([true, false])
        end

        context 'when email object is nil' do
          before do
            allow_any_instance_of(VAProfileRedis::V2::ContactInformation).to receive(:email).and_return(nil)
          end

          it 'returns nil for contact_email_verified when email is nil' do
            expect(vet360_info[:contact_email_verified]).to be_nil
          end
        end

        it 'sets the status to 200' do
          VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200',
                           match_requests_on: %i[method body], allow_playback_repeats: true) do
            expect(subject.status).to eq 200
          end
        end
      end

      context 'with a rescued error' do
        let(:message) { 'the server responded with status 503' }
        let(:error_body) { { 'status' => 'some service unavailable status' } }

        before do
          allow_any_instance_of(User).to receive(:vet360_contact_info).and_raise(
            Common::Client::Errors::ClientError.new(message, 503, error_body)
          )
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          results = Users::Profile.new(user).pre_serialize
          error   = results.errors.first

          expect(error[:external_service]).to eq 'VAProfile'
          expect(error[:start_time]).to be_present
          expect(error[:description]).to be_present
          expect(error[:status]).to eq 503
        end

        it 'sets the status to 296' do
          expect(subject.status).to eq 296
        end
      end
    end

    describe '#prefills_available' do
      it 'populates with an array of available prefills' do
        expect(subject.prefills_available).to be_present
      end

      context 'when user cannot access prefill data' do
        before do
          allow_any_instance_of(UserIdentity).to receive(:blank?).and_return(true)
        end

        it 'returns an empty array' do
          expect(subject.prefills_available).to eq []
        end
      end
    end

    describe '#services' do
      it 'returns an array of authorized services', :aggregate_failures do
        expect(subject.services.class).to eq Array
        expect(subject.services).to include 'facilities', 'hca', 'edu-benefits'
      end
    end

    describe '#session_data' do
      let(:scaffold_with_ssoe) { Users::Profile.new(user, { ssoe_transactionid: 'a' }).pre_serialize }

      it 'no session object indicates no SSOe authentication' do
        expect(subject.session)
          .to eq({ auth_broker: SAML::URLService::BROKER_CODE, ssoe: false, transactionid: nil })
      end

      it 'with a transaction in the Session shows a SSOe authentication' do
        expect(scaffold_with_ssoe.session)
          .to eq({ auth_broker: SAML::URLService::BROKER_CODE, ssoe: true, transactionid: 'a' })
      end
    end

    describe '#log_external_service_error' do
      let(:logging_user) { build(:user, :loa3, vet360_id: '1', uuid: 'test-uuid') }
      let(:logging_profile) { described_class.new(logging_user) }

      context 'when VA Profile service returns an error' do
        let(:vet360_error) do
          Common::Client::Errors::ClientError.new('Vet360 error', 502, {})
        end
        let(:vet_status_error) do
          Common::Client::Errors::ClientError.new('VAProfile error', 502, {})
        end
        let(:expected_va_profile_log_hash) do
          {
            'user_uuid' => 'test-uuid',
            'loa' => { 'current' => 3, 'highest' => 3 },
            'error' => hash_including('external_service' => 'VAProfile')
          }
        end

        it 'logs errors for vet360_contact_information' do
          allow(logging_user).to receive(:vet360_contact_info).and_raise(vet360_error)
          expect(Rails.logger).to receive(:warn) do |message, log_arg|
            expect(message).to eq('Users::Profile external service error')
            log_hash = JSON.parse(log_arg)
            expect(log_hash).to include(expected_va_profile_log_hash)
            expect(log_hash['error']['method']).to eq('vet360_contact_information')
          end
          logging_profile.send(:vet360_contact_information)
        end

        it 'logs errors for veteran_status' do
          allow(logging_user).to receive(:veteran?).and_raise(vet_status_error)
          expect(Rails.logger).to receive(:warn) do |message, log_arg|
            expect(message).to eq('Users::Profile external service error')
            log_hash = JSON.parse(log_arg)
            expect(log_hash).to include(expected_va_profile_log_hash)
            expect(log_hash['error']['method']).to eq('veteran_status')
          end
          logging_profile.send(:veteran_status)
        end
      end

      context 'when MPI service returns an error' do
        let(:mpi_error) { Common::Client::Errors::ClientError.new('MPI error', 502, {}) }
        let(:expected_mpi_log_hash) do
          {
            'user_uuid' => 'test-uuid',
            'loa' => { 'current' => 3, 'highest' => 3 },
            'error' => hash_including('external_service' => 'MVI')
          }
        end

        it 'logs errors for mpi_profile' do
          allow(logging_user).to receive_messages(
            mpi_status: :error, mpi_error:
          )
          expect(Rails.logger).to receive(:warn) do |message, log_arg|
            expect(message).to eq('Users::Profile external service error')
            log_hash = JSON.parse(log_arg)
            expect(log_hash).to include(expected_mpi_log_hash)
            expect(log_hash['error']['method']).to eq('mpi_profile')
          end
          logging_profile.send(:mpi_profile)
        end
      end
    end

    describe '#scheduling_preferences_pilot_eligible' do
      let(:users_profile) { Users::Profile.new(user) }
      let(:visn_service) { instance_double(UserVisnService) }
      let(:result) { users_profile.send(:scheduling_preferences_pilot_eligible) }

      before do
        allow(UserVisnService).to receive(:new).with(user).and_return(visn_service)
      end

      context 'when profile_scheduling_preferences feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences, user).and_return(false)
        end

        it 'returns false' do
          expect(visn_service).not_to receive(:in_pilot_visn?)
          expect(result).to be false
        end
      end

      context 'when profile_scheduling_preferences feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences, user).and_return(true)
        end

        context 'when user is in pilot VISN' do
          before do
            allow(visn_service).to receive(:in_pilot_visn?).and_return(true)
          end

          it 'returns true' do
            expect(result).to be true
          end
        end

        context 'when user is not in pilot VISN' do
          before do
            allow(visn_service).to receive(:in_pilot_visn?).and_return(false)
          end

          it 'returns false' do
            expect(result).to be false
          end
        end

        context 'when VISN service raises an error' do
          let(:error_message) { 'VISN service error' }

          before do
            allow(visn_service).to receive(:in_pilot_visn?).and_raise(StandardError, error_message)
            allow(Rails.logger).to receive(:error)
          end

          it 'logs the error and returns false' do
            expect(Rails.logger)
              .to receive(:error)
              .with("Error checking scheduling preferences pilot eligibility: #{error_message}")
            expect(result).to be false
          end
        end
      end
    end

    describe 'mpi_profile integration with scheduling_preferences_pilot_eligible' do
      let(:users_profile) { Users::Profile.new(user) }
      let(:mpi_profile_result) { users_profile.send(:mpi_profile) }

      before do
        allow(user).to receive_messages(loa3?: true, mpi_status: :ok)
        allow(user).to receive_messages(
          birth_date_mpi: '1980-01-01',
          last_name_mpi: 'Doe',
          gender_mpi: 'M',
          given_names: ['John'],
          cerner_id: nil,
          cerner_facility_ids: [],
          va_treatment_facility_ids: %w[402 515],
          va_patient?: true,
          mhv_account_state: 'OK',
          active_mhv_ids: ['12345']
        )
      end

      context 'when user is eligible for scheduling preferences pilot' do
        before do
          allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences, user).and_return(true)
          allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(true)
        end

        it 'includes scheduling_preferences_pilot_eligible as true in mpi_profile' do
          expect(mpi_profile_result[:scheduling_preferences_pilot_eligible]).to be true
        end
      end

      context 'when user is not eligible for scheduling preferences pilot' do
        before do
          allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences, user).and_return(false)
        end

        it 'includes scheduling_preferences_pilot_eligible as false in mpi_profile' do
          expect(mpi_profile_result[:scheduling_preferences_pilot_eligible]).to be false
        end
      end
    end

    describe 'mpi_profile integration with oh_migration_info' do
      let(:users_profile) { Users::Profile.new(user) }
      let(:mpi_profile_result) { users_profile.send(:mpi_profile) }

      before do
        allow(user).to receive_messages(loa3?: true, mpi_status: :ok)
        allow(user).to receive_messages(
          birth_date_mpi: '1980-01-01',
          last_name_mpi: 'Doe',
          gender_mpi: 'M',
          given_names: ['John'],
          cerner_id: nil,
          cerner_facility_ids: [],
          va_treatment_facility_ids: %w[516 517],
          va_patient?: true,
          mhv_account_state: 'OK',
          active_mhv_ids: ['12345']
        )
      end

      context 'when user has facilities in oh_migrations_list' do
        before do
          allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list)
            .and_return('2026-03-03:[516,Columbus VA],[517,Toledo VA]')
        end

        it 'includes oh_migration_info hash in mpi_profile' do
          expect(mpi_profile_result).to have_key(:oh_migration_info)
          expect(mpi_profile_result[:oh_migration_info]).to be_a(Hash)
        end

        it 'includes user_facility_migrating_to_oh in oh_migration_info' do
          expect(mpi_profile_result[:oh_migration_info]).to have_key(:user_facility_migrating_to_oh)
        end

        it 'includes migration_schedules in oh_migration_info' do
          expect(mpi_profile_result[:oh_migration_info]).to have_key(:migration_schedules)
          expect(mpi_profile_result[:oh_migration_info][:migration_schedules]).to be_an(Array)
        end

        it 'returns migration schedules for matching facilities' do
          schedules = mpi_profile_result[:oh_migration_info][:migration_schedules]
          expect(schedules.length).to eq(1)
        end

        it 'includes facilities matching user va_treatment_facility_ids' do
          schedules = mpi_profile_result[:oh_migration_info][:migration_schedules]
          facility_ids = schedules.first[:facilities].map { |f| f[:facility_id] }
          expect(facility_ids).to contain_exactly('516', '517')
        end

        it 'includes migration_date in response' do
          schedules = mpi_profile_result[:oh_migration_info][:migration_schedules]
          expect(schedules.first[:migration_date]).to eq('March 3, 2026')
        end

        it 'includes migration_status in response' do
          schedules = mpi_profile_result[:oh_migration_info][:migration_schedules]
          expect(schedules.first[:migration_status]).to be_present
        end

        it 'includes phases in response' do
          schedules = mpi_profile_result[:oh_migration_info][:migration_schedules]
          expect(schedules.first[:phases]).to be_a(Hash)
        end
      end

      context 'when user has no facilities in oh_migrations_list' do
        before do
          allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list)
            .and_return('2026-03-03:[999,Other VA]')
        end

        it 'returns empty array for migration_schedules' do
          expect(mpi_profile_result[:oh_migration_info][:migration_schedules]).to eq([])
        end
      end

      context 'when oh_migrations_list is nil' do
        before do
          allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list).and_return(nil)
        end

        it 'returns empty array for migration_schedules' do
          expect(mpi_profile_result[:oh_migration_info][:migration_schedules]).to eq([])
        end
      end

      # NOTE: Error handling for get_migration_schedules is tested in
      # spec/lib/mhv/oh_facilities_helper/service_spec.rb
      # The service method rescues all errors and returns []
    end
  end
end
