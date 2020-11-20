# frozen_string_literal: true

require 'rails_helper'

describe Vet360Redis::ContactInformation do
  let(:user) { build :user, :loa3 }
  let(:contact_info) { Vet360Redis::ContactInformation.for_user(user) }
  let(:person) { build :person, telephones: telephones, permissions: permissions }
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
    allow(Vet360::Models::Person).to receive(:build_from).and_return(person)
  end

  let(:person_response) do
    raw_response = OpenStruct.new(status: 200, body: { 'bio' => person.to_hash })

    Vet360::ContactInformation::PersonResponse.from(raw_response)
  end

  context 'with a 404 from get_person', skip_vet360: true do
    let(:get_person_calls) { 'once' }

    before do
      allow(Settings.vet360.contact_information).to receive(:cache_enabled).and_return(true)

      service = double
      allow(Vet360::ContactInformation::Service).to receive(:new).with(user).and_return(service)
      expect(service).to receive(:get_person).public_send(
        get_person_calls
      ).and_return(
        Vet360::ContactInformation::PersonResponse.new(404, person: nil)
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
        Vet360Redis::Cache.invalidate(user)

        expect(Vet360Redis::ContactInformation.for_user(user).email).to eq(nil)
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
          Vet360::ContactInformation::Service
        ).to receive(:get_person).and_return(person_response)

        expect(contact_info.redis_namespace).to receive(:set).once if Settings.vet360.contact_information.cache_enabled
        expect_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).twice
        expect(contact_info.status).to eq 200
        expect(contact_info.response.person).to have_deep_attributes(person)
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data', :aggregate_failures do
        contact_info.cache(user.uuid, person_response)

        expect_any_instance_of(Vet360::ContactInformation::Service).not_to receive(:get_person)
        expect(contact_info.response.person).to have_deep_attributes(person)
      end
    end
  end

  describe 'contact information attributes' do
    context 'with a successful response' do
      before do
        allow(Vet360::Models::Person).to receive(:build_from).and_return(person)
        allow_any_instance_of(
          Vet360::ContactInformation::Service
        ).to receive(:get_person).and_return(person_response)
      end

      describe '#email' do
        it 'returns the users email address object', :aggregate_failures do
          expect(contact_info.email).to eq person.emails.first
          expect(contact_info.email.class).to eq Vet360::Models::Email
        end
      end

      describe '#residential_address' do
        it 'returns the users residential address object', :aggregate_failures do
          residence = address_for Vet360::Models::Address::RESIDENCE

          expect(contact_info.residential_address).to eq residence
          expect(contact_info.residential_address.class).to eq Vet360::Models::Address
        end
      end

      describe '#mailing_address' do
        it 'returns the users mailing address object', :aggregate_failures do
          residence = address_for Vet360::Models::Address::CORRESPONDENCE

          expect(contact_info.mailing_address).to eq residence
          expect(contact_info.mailing_address.class).to eq Vet360::Models::Address
        end
      end

      describe '#home_phone' do
        it 'returns the users home phone object', :aggregate_failures do
          phone = phone_for Vet360::Models::Telephone::HOME

          expect(contact_info.home_phone).to eq phone
          expect(contact_info.home_phone.class).to eq Vet360::Models::Telephone
        end
      end

      describe '#mobile_phone' do
        it 'returns the users mobile phone object', :aggregate_failures do
          phone = phone_for Vet360::Models::Telephone::MOBILE

          expect(contact_info.mobile_phone).to eq phone
          expect(contact_info.mobile_phone.class).to eq Vet360::Models::Telephone
        end
      end

      describe '#work_phone' do
        it 'returns the users work phone object', :aggregate_failures do
          phone = phone_for Vet360::Models::Telephone::WORK

          expect(contact_info.work_phone).to eq phone
          expect(contact_info.work_phone.class).to eq Vet360::Models::Telephone
        end
      end

      describe '#temporary_phone' do
        it 'returns the users temporary phone object', :aggregate_failures do
          phone = phone_for Vet360::Models::Telephone::TEMPORARY

          expect(contact_info.temporary_phone).to eq phone
          expect(contact_info.temporary_phone.class).to eq Vet360::Models::Telephone
        end
      end

      describe '#fax_number' do
        it 'returns the users FAX object', :aggregate_failures do
          phone = phone_for Vet360::Models::Telephone::FAX

          expect(contact_info.fax_number).to eq phone
          expect(contact_info.fax_number.class).to eq Vet360::Models::Telephone
        end
      end

      describe '#text_permission' do
        it 'returns the users text permission object', :aggregate_failures do
          permission = permission_for Vet360::Models::Permission::TEXT

          expect(contact_info.text_permission).to eq permission
          expect(contact_info.text_permission.class).to eq Vet360::Models::Permission
        end
      end
    end

    context 'with an error response' do
      before do
        allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).and_raise(
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
          expect { contact_info.mailing_address }.to raise_error(
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

      describe '#text_permission' do
        it 'raises a Common::Exceptions::BackendServiceException error' do
          expect { contact_info.text_permission }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with an empty respose body' do
      let(:empty_response) do
        raw_response = OpenStruct.new(status: 500, body: nil)

        Vet360::ContactInformation::PersonResponse.from(raw_response)
      end

      before do
        allow(Vet360::Models::Person).to receive(:build_from).and_return(nil)
        allow_any_instance_of(
          Vet360::ContactInformation::Service
        ).to receive(:get_person).and_return(empty_response)
      end

      describe '#email' do
        it 'returns nil' do
          expect(contact_info.email).to be_nil
        end
      end

      describe '#residential_address' do
        it 'returns nil' do
          expect(contact_info.mailing_address).to be_nil
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

      describe '#text_permission' do
        it 'returns nil' do
          expect(contact_info.text_permission).to be_nil
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
