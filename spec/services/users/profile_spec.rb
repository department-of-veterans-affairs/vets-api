# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Profile do
  let(:user) { build(:user, :accountable) }
  let!(:in_progress_form) { create(:in_progress_form, user_uuid: user.uuid) }

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
    let(:profile) { subject.profile }
    let(:va_profile) { subject.va_profile }
    let(:veteran_status) { subject.veteran_status }

    subject { Users::Profile.new(user).pre_serialize }

    it 'should not include ssn anywhere', :aggregate_failures do
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

    context '#in_progress_forms' do
      it 'should include metadata' do
        expect(subject.in_progress_forms[0][:metadata]).to eq(in_progress_form.metadata)
      end
    end

    context '#account' do
      it 'should include account uuid' do
        expect(subject.account[:account_uuid]).to eq(user.account_uuid)
      end
    end

    context '#profile' do
      # --- positive tests ---
      context 'idme user' do
        it 'should include authn_context' do
          expect(profile[:authn_context]).to eq(nil)
        end

        it 'should include sign_in' do
          expect(profile[:sign_in]).to eq(service_name: 'idme')
        end

        context 'multifactor' do
          let(:user) { create(:user, :loa1, authn_context: 'multifactor') }

          it 'should include authn_context' do
            expect(profile[:authn_context]).to eq(nil)
          end

          it 'should include sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq('idme')
          end
        end
      end

      context 'mhv user' do
        let(:user) { create(:user, :mhv) }

        it 'should include authn_context' do
          expect(profile[:authn_context]).to eq('myhealthevet')
        end

        it 'should include sign_in' do
          expect(profile[:sign_in]).to eq(service_name: 'myhealthevet')
        end

        context 'multifactor' do
          let(:user) { create(:user, :loa1, authn_context: 'myhealthevet_multifactor') }

          it 'should include authn_context' do
            expect(profile[:authn_context]).to eq('myhealthevet')
          end

          it 'should include sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq('myhealthevet')
          end
        end

        context 'verified' do
          let(:user) { create(:user, :loa1, authn_context: 'myhealthevet_loa3') }

          it 'should include authn_context' do
            expect(profile[:authn_context]).to eq('myhealthevet')
          end

          it 'should include sign_in.service_name' do
            expect(profile[:sign_in][:service_name]).to eq('myhealthevet')
          end
        end
      end

      context 'dslogon user' do
        let(:user) { create(:user, :dslogon) }

        it 'should include authn_context' do
          expect(profile[:authn_context]).to eq('dslogon')
        end

        it 'should include sign_in.service_name' do
          expect(profile[:sign_in]).to eq(service_name: 'dslogon')
        end

        context 'multifactor' do
          let(:user) { create(:user, :loa1, authn_context: 'dslogon_multifactor') }

          it 'should include authn_context' do
            expect(profile[:authn_context]).to eq('dslogon')
          end

          it 'should include sign_in.service_name' do
            expect(profile[:sign_in]).to eq(service_name: 'dslogon')
          end
        end

        context 'verified' do
          let(:user) { create(:user, :loa1, authn_context: 'dslogon_loa3') }

          it 'should include authn_context' do
            expect(profile[:authn_context]).to eq('dslogon')
          end

          it 'should include sign_in.service_name' do
            expect(profile[:sign_in]).to eq(service_name: 'dslogon')
          end
        end
      end

      it 'should include email' do
        expect(profile[:email]).to eq(user.email)
      end

      it 'should include first_name' do
        expect(profile[:first_name]).to eq(user.first_name)
      end

      it 'should include middle_name' do
        expect(profile[:middle_name]).to eq(user.middle_name)
      end

      it 'should include last_name' do
        expect(profile[:last_name]).to eq(user.last_name)
      end

      it 'should include birth_date' do
        expect(profile[:birth_date]).to eq(user.birth_date)
      end

      it 'should include gender' do
        expect(profile[:gender]).to eq(user.gender)
      end

      it 'should include zip' do
        expect(profile[:zip]).to eq(user.zip)
      end

      it 'should include last_signed_in' do
        expect(profile[:last_signed_in].httpdate).to eq(user.last_signed_in.httpdate)
      end

      # --- negative tests ---
      it 'should not include uuid in the profile' do
        expect(profile[:uuid]).to be_nil
      end

      it 'should not include edipi in the profile' do
        expect(profile[:edipi]).to be_nil
      end

      it 'should not include participant_id in the profile' do
        expect(profile[:participant_id]).to be_nil
      end
    end

    context '#va_profile' do
      context 'when user.mvi is not nil' do
        it 'should include birth_date' do
          expect(va_profile[:birth_date]).to eq(user.va_profile[:birth_date])
        end

        it 'should include family_name' do
          expect(va_profile[:family_name]).to eq(user.va_profile[:family_name])
        end

        it 'should include gender' do
          expect(va_profile[:gender]).to eq(user.va_profile[:gender])
        end

        it 'should include given_names' do
          expect(va_profile[:given_names]).to eq(user.va_profile[:given_names])
        end

        it 'should include status' do
          expect(va_profile[:status]).to eq('OK')
        end

        it 'sets the status to 200' do
          expect(subject.status).to eq 200
        end
      end

      context 'when user.mvi is nil' do
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

      context 'when user.mvi is not found' do
        before { stub_mvi_not_found }

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

    context '#veteran_status' do
      context 'when a veteran status is succesfully returned' do
        it 'should include is_veteran' do
          expect(veteran_status[:is_veteran]).to eq(user.veteran?)
        end

        it 'should include status' do
          expect(veteran_status[:status]).to eq('OK')
        end

        it 'should include served_in_military' do
          expect(veteran_status[:served_in_military]).to eq(user.served_in_military?)
        end

        it 'sets the status to 200' do
          expect(subject.status).to eq 200
        end
      end

      context 'when a veteran status is not found' do
        before(:each) do
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
        before(:each) do
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

    context '#vet360_contact_information' do
      context 'with an loa1 user' do
        let(:user) { build(:user, :loa1) }

        it 'should return an empty hash', :aggregate_failures do
          expect(user.vet360_contact_info).to be_nil
          expect(subject.vet360_contact_information).to eq({})
        end
      end

      context 'with a valid user' do
        let(:user) { build(:user, :loa3) }
        let(:vet360_info) { subject.vet360_contact_information }

        it 'should be populated', :aggregate_failures do
          expect(user.vet360_contact_info).not_to be_nil
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

    context '#prefills_available' do
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

    context '#services' do
      it 'returns an array of authorized services', :aggregate_failures do
        expect(subject.services.class).to eq Array
        expect(subject.services).to include 'facilities', 'hca', 'edu-benefits'
      end
    end
  end
end
