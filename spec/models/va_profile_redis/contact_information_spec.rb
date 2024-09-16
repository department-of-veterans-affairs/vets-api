# frozen_string_literal: true

require 'rails_helper'

describe VAProfileRedis::ContactInformation do
  let(:user) { build :user, :loa3 }

  let(:service) do
    if Flipper.enabled?(:va_v3_contact_information_service)
      VAProfile::V2::ContactInformation::Service
    else
      VAProfile::ContactInformation::Service
    end
  end

  let(:contact_person_response) do
    if Flipper.enabled?(:va_v3_contact_information_service)
      VAProfile::V2::ContactInformation::PersonResponse
    else
      VAProfile::ContactInformation::PersonResponse
    end
  end

  let(:contact_info) { VAProfileRedis::ContactInformation.for_user(user) }

  let(:person) do
    if Flipper.enabled?(:va_v3_contact_information_service)
      build :person_v2, telephones:
    else
      build :person, telephones:, permissions:
    end
  end

  let(:person_response) do
    raw_response = OpenStruct.new(status: 200, body: { 'bio' => person.to_hash })
    contact_person_response.from(raw_response)
  end

  let(:telephones) do
    [
      build(:telephone),
      build(:telephone, :home),
      build(:telephone, :work),
      build(:telephone, :temporary),
      build(:telephone, :fax)
    ]
  end
  let(:permissions) do
    [
      build(:permission)
    ]
  end

  before do
    allow(VAProfile::Models::Person).to receive(:build_from).and_return(person)
  end

  [404, 400].each do |status|
    context "with a #{status} from get_person", :skip_vet360 do
      let(:get_person_calls) { 'once' }

      before do
        allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
        double_service = double
        allow(service).to receive(:new).with(user).and_return(double_service)
        expect(double_service).to receive(:get_person).public_send(
          get_person_calls
        ).and_return(
          contact_person_response.new(status, person: nil)
        )
      end

      it 'caches the empty response' do
        expect(contact_info.email).to eq(nil)
        expect(contact_info.home_phone).to eq(nil)
      end

      context 'when the cache is destroyed' do
        let(:get_person_calls) { 'twice' }

        it 'makes a new request' do
          expect(contact_info.email).to eq(nil)
          VAProfileRedis::Cache.invalidate(user)

          expect(VAProfileRedis::ContactInformation.for_user(user).email).to eq(nil)
        end
      end
    end
  end

  describe '.new' do
    it 'creates an instance with user attributes' do
      expect(contact_info.user).to eq(user)
    end
  end

  describe '#response' do
    context 'when the cache is empty' do
      it 'caches and return the response', :aggregate_failures do
        allow_any_instance_of(
          service
        ).to receive(:get_person).and_return(person_response)

        if VAProfile::Configuration::SETTINGS.contact_information.cache_enabled
          expect(contact_info.redis_namespace).to receive(:set).once
        end
        expect_any_instance_of(service).to receive(:get_person).twice
        expect(contact_info.status).to eq 200
        expect(contact_info.response.person).to have_deep_attributes(person)
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data', :aggregate_failures do
        contact_info.cache(user.uuid, person_response)

        expect_any_instance_of(service).not_to receive(:get_person)
        expect(contact_info.response.person).to have_deep_attributes(person)
      end
    end
  end

  describe 'contact information attributes' do
    context 'with a successful response' do
      before do
        allow(VAProfile::Models::Person).to receive(:build_from).and_return(person)
        allow_any_instance_of(
          service
        ).to receive(:get_person).and_return(person_response)
      end

      describe '#email' do
        it 'returns the users email address object', :aggregate_failures do
          expect(contact_info.email).to eq person.emails.first
          expect(contact_info.email.class).to eq VAProfile::Models::Email
        end
      end

      unless Flipper.enabled?(:va_v3_contact_information_service)
        describe '#residential_address' do
          it 'returns the users residential address object', :aggregate_failures do
            residence = address_for VAProfile::Models::Address::RESIDENCE

            expect(contact_info.residential_address).to eq residence
            expect(contact_info.residential_address.class).to eq VAProfile::Models::Address
          end
        end

        describe '#mailing_address' do
          it 'returns the users mailing address object', :aggregate_failures do
            residence = address_for VAProfile::Models::Address::CORRESPONDENCE

            expect(contact_info.mailing_address).to eq residence
            expect(contact_info.mailing_address.class).to eq VAProfile::Models::Address
          end
        end
      end
      if Flipper.enabled?(:va_v3_contact_information_service)
        describe '#residential_address' do
          it 'returns the users residential address object', :aggregate_failures do
            residence = address_for VAProfile::Models::V2::Address::RESIDENCE
            expect(contact_info.residential_address).to eq residence
            # expect(contact_info.residential_address.class).to eq VAProfile::Models::V2::Address
          end
        end

        describe '#mailing_address' do
          it 'returns the users mailing address object', :aggregate_failures do
            residence = address_for VAProfile::Models::V2::Address::CORRESPONDENCE

            expect(contact_info.mailing_address).to eq residence
            # expect(contact_info.mailing_address.class).to eq VAProfile::Models::V2::Address
          end
        end
      end

      describe '#home_phone' do
        it 'returns the users home phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::HOME

          expect(contact_info.home_phone).to eq phone
          expect(contact_info.home_phone.class).to eq VAProfile::Models::Telephone
        end
      end

      describe '#mobile_phone' do
        it 'returns the users mobile phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::MOBILE

          expect(contact_info.mobile_phone).to eq phone
          expect(contact_info.mobile_phone.class).to eq VAProfile::Models::Telephone
        end
      end

      describe '#work_phone' do
        it 'returns the users work phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::WORK

          expect(contact_info.work_phone).to eq phone
          expect(contact_info.work_phone.class).to eq VAProfile::Models::Telephone
        end
      end

      describe '#temporary_phone' do
        it 'returns the users temporary phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::TEMPORARY

          expect(contact_info.temporary_phone).to eq phone
          expect(contact_info.temporary_phone.class).to eq VAProfile::Models::Telephone
        end
      end

      describe '#fax_number' do
        it 'returns the users FAX object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::FAX
          expect(contact_info.fax_number).to eq phone
          expect(contact_info.fax_number.class).to eq VAProfile::Models::Telephone
        end
      end

      if !Flipper.enabled?(:va_v3_contact_information_service)
        describe '#text_permission' do
          it 'returns the users text permission object', :aggregate_failures do
            permission = permission_for VAProfile::Models::Permission::TEXT

            expect(contact_info.text_permission).to eq permission
            expect(contact_info.text_permission.class).to eq VAProfile::Models::Permission
          end
        end
      end
    end

    context 'with an error response' do
      before do
        allow_any_instance_of(service).to receive(:get_person).and_raise(
          Common::Exceptions::BackendServiceException
        )
      end

      describe '#email' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.email }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      describe '#residential_address' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.residential_address }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      describe '#mailing_address' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.mailing_address }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      describe '#home_phone' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.home_phone }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      describe '#mobile_phone' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.mobile_phone }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      describe '#work_phone' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.work_phone }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      describe '#temporary_phone' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.temporary_phone }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      describe '#fax_number' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.fax_number }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
      if !Flipper.enabled?(:va_v3_contact_information_service)
        describe '#text_permission' do
          it 'raises a Common::Exceptions::BackendServiceException error' do
            expect { contact_info.text_permission }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end

    context 'with an empty respose body' do
      let(:empty_response) do
        raw_response = OpenStruct.new(status: 500, body: nil)

        contact_person_response.from(raw_response)
      end

      before do
        allow(VAProfile::Models::Person).to receive(:build_from).and_return(nil)
        allow_any_instance_of(
          service
        ).to receive(:get_person).and_return(empty_response)
      end

      describe '#email' do
        it 'returns nil' do
          expect(contact_info.email).to be_nil
        end
      end

      describe '#residential_address' do
        it 'returns nil' do
          expect(contact_info.residential_address).to be_nil
        end
      end

      describe '#mailing_address' do
        it 'returns nil' do
          expect(contact_info.mailing_address).to be_nil
        end
      end

      describe '#home_phone' do
        it 'returns nil' do
          expect(contact_info.home_phone).to be_nil
        end
      end

      describe '#mobile_phone' do
        it 'returns nil' do
          expect(contact_info.mobile_phone).to be_nil
        end
      end

      describe '#work_phone' do
        it 'returns nil' do
          expect(contact_info.work_phone).to be_nil
        end
      end

      describe '#temporary_phone' do
        it 'returns nil' do
          expect(contact_info.temporary_phone).to be_nil
        end
      end
      describe '#fax_number' do
        it 'returns nil' do
          expect(contact_info.fax_number).to be_nil
        end
      end
      if !Flipper.enabled?(:va_v3_contact_information_service)
        describe '#text_permission' do
          it 'returns nil' do
            expect(contact_info.text_permission).to be_nil
          end
        end
      end
    end
  end
end

def address_for(address_type)
  person.addresses.find { |address| address.address_pou == address_type }
end

def phone_for(phone_type)
  person.telephones.find { |telephone| telephone.phone_type == phone_type }
end

def permission_for(permission_type)
  person.permissions.find { |permission| permission.permission_type == permission_type }
end
