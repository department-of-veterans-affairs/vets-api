# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Profile do
  let(:user) { build(:user, :accountable) }
  let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
  let!(:in_progress_form_user_uuid) { create(:in_progress_form, user_uuid: user.uuid) }
  let!(:in_progress_form_user_account) { create(:in_progress_form, user_account: user.user_account) }

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
        account = build(:account)

        expect { Users::Profile.new(account) }.to raise_error(Common::Exceptions::ParameterMissing)
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

    describe '#account' do
      it 'includes account uuid' do
        expect(subject.account[:account_uuid]).to eq(user.account_uuid)
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

      context 'dslogon user' do
        let(:user) { create(:user, :dslogon) }
        let!(:user_verification) { create(:dslogon_user_verification, dslogon_uuid: user.edipi) }

        it 'includes sign_in' do
          expect(profile[:sign_in]).to eq(service_name: SAML::User::DSLOGON_CSID,
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
      context 'when user.mpi is not nil' do
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
      end

      context 'when user.mpi is nil' do
        let(:user) { build(:user) }

        it 'returns va_profile as null' do
          expect(va_profile).to be_nil
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          error = subject.errors.first

          expect(error[:external_service]).to eq 'MVI'
          expect(error[:start_time]).to be_present
          expect(error[:description]).to include 'Not authorized'
          expect(error[:status]).to eq 401
        end

        it 'sets the status to 296' do
          expect(subject.status).to eq 296
        end
      end

      context 'when user.mpi is not found' do
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

      context 'with a LOA1 user' do
        let(:user) { build(:user, :loa1) }

        it 'returns va_profile as null' do
          expect(veteran_status).to be_nil
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          VCR.use_cassette('va_profile/veteran_status/veteran_status_401_oid_blank', match_requests_on: %i[method body],
                                                                                     allow_playback_repeats: true) do
            vaprofile_error = subject.errors.last

            expect(vaprofile_error[:external_service]).to eq 'VAProfile'
            expect(vaprofile_error[:start_time]).to be_present
            expect(vaprofile_error[:description]).to include 'VA Profile failure'
            expect(vaprofile_error[:status]).to eq 401
          end
        end

        it 'sets the status to 296' do
          expect(subject.status).to eq 296
        end
      end
    end

    describe '#vet360_contact_information' do
      context 'with an loa1 user' do
        let(:user) { build(:user, :loa1) }

        it 'returns an empty hash', :aggregate_failures do
          expect(user.vet360_contact_info).to be_nil
          expect(subject.vet360_contact_information).to eq({})
        end
      end

      context 'with a valid user' do
        let(:user) { build(:user, :loa3, vet360_id: '1') }
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
  end
end
