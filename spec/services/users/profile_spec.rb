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
        account = build :account

        expect { Users::Profile.new(account) }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end
  end

  describe '#pre_serialize' do
    subject { Users::Profile.new(user).pre_serialize }

    let(:profile) { subject.profile }
    let(:va_profile) { subject.va_profile }
    let(:veteran_status) { subject.veteran_status }

    it 'does not include ssn anywhere', :aggregate_failures do
      expect(subject.try(:ssn)).to be_nil
      expect(subject.profile['ssn']).to be_nil
      expect(subject.va_profile['ssn']).to be_nil
    end

    it 'sets the status to 200' do
      expect(subject.status).to eq 200
    end

    it 'sets the errors to nil' do
      expect(subject.errors).to be_nil
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
                                          client_id: SAML::URLService::WEB_CLIENT_ID)
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

        it 'includes sign_in' do
          expect(profile[:sign_in]).to eq(service_name: SAML::User::MHV_ORIGINAL_CSID,
                                          auth_broker: SAML::URLService::BROKER_CODE,
                                          client_id: SAML::URLService::WEB_CLIENT_ID)
        end

        context 'multifactor' do
          let(:user) { create(:user, :loa1, authn_context: 'myhealthevet_multifactor') }

          it 'includes sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq(SAML::User::MHV_ORIGINAL_CSID)
          end
        end

        context 'verified' do
          let(:user) { create(:user, :loa1, authn_context: 'myhealthevet_loa3') }

          it 'includes sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq(SAML::User::MHV_ORIGINAL_CSID)
          end
        end
      end

      context 'dslogon user' do
        let(:user) { create(:user, :dslogon) }

        it 'includes sign_in' do
          expect(profile[:sign_in]).to eq(service_name: SAML::User::DSLOGON_CSID,
                                          auth_broker: SAML::URLService::BROKER_CODE,
                                          client_id: SAML::URLService::WEB_CLIENT_ID)
        end

        context 'multifactor' do
          let(:user) { create(:user, :loa1, authn_context: 'dslogon_multifactor') }

          it 'includes sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq(SAML::User::DSLOGON_CSID)
          end
        end

        context 'verified' do
          let(:user) { create(:user, :loa1, authn_context: 'dslogon_loa3') }

          it 'includes sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq(SAML::User::DSLOGON_CSID)
          end
        end
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

      it 'includes inherited_proof_verified' do
        expect(profile[:inherited_proof_verified]).to eq(user.inherited_proof_verified)
      end

      # --- negative tests ---
      it 'does not include uuid in the profile' do
        expect(profile[:uuid]).to be_nil
      end

      it 'does not include edipi in the profile' do
        expect(profile[:edipi]).to be_nil
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
          expect(subject.status).to eq 200
        end
      end

      context 'when user.mpi is nil' do
        let(:user) { build :user }

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
          expect(veteran_status[:is_veteran]).to eq(user.veteran?)
        end

        it 'includes status' do
          expect(veteran_status[:status]).to eq(Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok])
        end

        it 'includes served_in_military' do
          expect(veteran_status[:served_in_military]).to eq(user.served_in_military?)
        end

        it 'sets the status to 200' do
          expect(subject.status).to eq 200
        end
      end

      context 'when a veteran status is not found' do
        before do
          allow_any_instance_of(
            EMISRedis::VeteranStatus
          ).to receive(:veteran?).and_raise(EMISRedis::VeteranStatus::RecordNotFound.new(status: 404))
        end

        it 'sets veteran_status to nil' do
          expect(veteran_status).to be_nil
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          error = subject.errors.first

          expect(error[:external_service]).to eq 'EMIS'
          expect(error[:start_time]).to be_present
          expect(error[:description]).to include 'NOT_FOUND'
          expect(error[:status]).to eq 404
        end

        it 'sets the status to 296' do
          expect(subject.status).to eq 296
        end
      end

      context 'when a veteran status call returns an error' do
        before do
          allow_any_instance_of(
            EMISRedis::VeteranStatus
          ).to receive(:veteran?).and_raise(Common::Client::Errors::ClientError.new(nil, 503))
        end

        it 'sets veteran_status to nil' do
          expect(veteran_status).to be_nil
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          error = subject.errors.first

          expect(error[:external_service]).to eq 'EMIS'
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

        before do
          allow_any_instance_of(
            EMISRedis::VeteranStatus
          ).to receive(:veteran?).and_raise(EMISRedis::VeteranStatus::NotAuthorized.new(status: 401))
        end

        it 'returns va_profile as null' do
          expect(veteran_status).to be_nil
        end

        it 'populates the #errors array with the serialized error', :aggregate_failures do
          emis_error = subject.errors.last

          expect(emis_error[:external_service]).to eq 'EMIS'
          expect(emis_error[:start_time]).to be_present
          expect(emis_error[:description]).to include 'NOT_AUTHORIZED'
          expect(emis_error[:status]).to eq 401
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
          expect(vet360_info[:email]).to be_present
          expect(vet360_info[:residential_address]).to be_present
          expect(vet360_info[:mailing_address]).to be_present
          expect(vet360_info[:home_phone]).to be_present
          expect(vet360_info[:mobile_phone]).to be_present
          expect(vet360_info[:work_phone]).to be_present
          expect(vet360_info[:fax_number]).to be_present
          expect(vet360_info[:temporary_phone]).to be_present
          expect(vet360_info[:text_permission]).to be_present
        end

        it 'sets the status to 200' do
          expect(subject.status).to eq 200
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

          expect(error[:external_service]).to eq 'Vet360'
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
