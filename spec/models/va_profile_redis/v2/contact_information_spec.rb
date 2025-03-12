# frozen_string_literal: true

require 'rails_helper'

describe VAProfileRedis::V2::ContactInformation do
  let(:user) { build(:user, :loa3) }
  let(:person_response) do
    raw_response = OpenStruct.new(status: 200, body: { 'bio' => person.to_hash })

    VAProfile::V2::ContactInformation::PersonResponse.from(raw_response)
  end
  let(:contact_info) { VAProfileRedis::V2::ContactInformation.for_user(user) }
  let(:person) { build(:person_v2, telephones:) }
  let(:telephones) do
    [
      build(:telephone),
      build(:telephone, :home),
      build(:telephone, :work),
      build(:telephone, :temporary),
      build(:telephone, :fax)
    ]
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    allow(VAProfile::Models::V3::Person).to receive(:build_from).and_return(person)
  end

  [404, 400].each do |status|
    context "with a #{status} from get_person", :skip_vet360 do
      let(:get_person_calls) { 'once' }

      before do
        allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)

        service = double
        allow(VAProfile::V2::ContactInformation::Service).to receive(:new).with(user).and_return(service)
        expect(service).to receive(:get_person).public_send(
          get_person_calls
        ).and_return(
          VAProfile::V2::ContactInformation::PersonResponse.new(status, person: nil)
        )
      end

      it 'caches the empty response' do
        VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
          expect(contact_info.email).to be_nil
          expect(contact_info.home_phone).to be_nil
        end
      end

      context 'when the cache is destroyed' do
        let(:get_person_calls) { 'twice' }

        it 'makes a new request' do
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.email).to be_nil
          end
          VAProfileRedis::V2::Cache.invalidate(user)

          expect(VAProfileRedis::V2::ContactInformation.for_user(user).email).to be_nil
        end
      end
    end
  end

  describe '.new' do
    it 'creates an instance with user attributes' do
      VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
        expect(contact_info.user).to eq(user)
      end
    end
  end

  describe '#response' do
    context 'when the cache is empty' do
      it 'caches and return the response', :aggregate_failures do
        allow_any_instance_of(
          VAProfile::V2::ContactInformation::Service
        ).to receive(:get_person).and_return(person_response)

        VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
          if VAProfile::Configuration::SETTINGS.contact_information.cache_enabled
            expect(contact_info.redis_namespace).to receive(:set).once
          end
          expect_any_instance_of(VAProfile::V2::ContactInformation::Service).to receive(:get_person).once
          expect(contact_info.status).to eq 200
          expect(contact_info.response.person).to have_deep_attributes(person)
        end
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data', :aggregate_failures do
        VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
          contact_info.cache(user.icn, person_response)
          expect_any_instance_of(VAProfile::V2::ContactInformation::Service).not_to receive(:get_person)
          expect(contact_info.response.person).to have_deep_attributes(person)
        end
      end
    end
  end

  describe 'contact information attributes' do
    context 'with a successful response' do
      before do
        allow(VAProfile::Models::V3::Person).to receive(:build_from).and_return(person)
        allow_any_instance_of(
          VAProfile::V2::ContactInformation::Service
        ).to receive(:get_person).and_return(person_response)
      end

      describe '#email' do
        it 'returns the users email address object', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.email).to eq person.emails.first
            expect(contact_info.email.class).to eq VAProfile::Models::Email
          end
        end
      end

      describe '#residential_address' do
        it 'returns the users residential address object', :aggregate_failures do
          residence = address_for VAProfile::Models::V3::Address::RESIDENCE
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.residential_address).to eq residence
            expect(contact_info.residential_address.class).to eq VAProfile::Models::V3::Address
          end
        end
      end

      describe '#mailing_address' do
        it 'returns the users mailing address object', :aggregate_failures do
          correspondence = address_for VAProfile::Models::V3::Address::CORRESPONDENCE
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.mailing_address).to eq correspondence
            expect(contact_info.mailing_address.class).to eq VAProfile::Models::V3::Address
          end
        end
      end

      describe '#home_phone' do
        it 'returns the users home phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::HOME
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.home_phone).to eq phone
            expect(contact_info.home_phone.class).to eq VAProfile::Models::Telephone
          end
        end
      end

      describe '#mobile_phone' do
        it 'returns the users mobile phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::MOBILE
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.mobile_phone).to eq phone
            expect(contact_info.mobile_phone.class).to eq VAProfile::Models::Telephone
          end
        end
      end

      describe '#work_phone' do
        it 'returns the users work phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::WORK
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.work_phone).to eq phone
            expect(contact_info.work_phone.class).to eq VAProfile::Models::Telephone
          end
        end
      end

      describe '#temporary_phone' do
        it 'returns the users temporary phone object', :aggregate_failures do
          phone = phone_for VAProfile::Models::Telephone::TEMPORARY
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.temporary_phone).to eq phone
            expect(contact_info.temporary_phone.class).to eq VAProfile::Models::Telephone
          end
        end
      end

      describe '#fax_number' do
        it 'returns the users FAX object', :aggregate_failures do
          fax = phone_for VAProfile::Models::Telephone::FAX
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            expect(contact_info.fax_number).to eq fax
            expect(contact_info.fax_number.class).to eq VAProfile::Models::Telephone
          end
        end
      end
    end

    context 'with an error response' do
      before do
        allow_any_instance_of(VAProfile::V2::ContactInformation::Service).to receive(:get_person).and_raise(
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
    end

    context 'with an empty respose body' do
      let(:empty_response) do
        raw_response = OpenStruct.new(status: 500, body: nil)

        VAProfile::V2::ContactInformation::PersonResponse.from(raw_response)
      end

      before do
        allow(VAProfile::Models::V3::Person).to receive(:build_from).and_return(nil)
        allow_any_instance_of(
          VAProfile::V2::ContactInformation::Service
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
    end
  end
end

def address_for(address_type)
  person.addresses.find { |address| address.address_pou == address_type }
end

def phone_for(phone_type)
  person.telephones.find { |telephone| telephone.phone_type == phone_type }
end
