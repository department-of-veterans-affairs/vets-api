# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::PayloadBuilder::SubmitterProfile do
  describe '#call' do
    subject(:builder) { described_class.new(inquiry_params: params, user: authorized_user, inquiry_details:) }

    let(:authorized_user) { build(:user, :accountable_with_sec_id, icn: '234', edipi: '123') }
    let(:cached_data) do
      data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
      JSON.parse(data, symbolize_names: true)
    end
    let(:level_of_authentication) { 'Personal' }
    let(:inquiry_details) do
      {
        inquiry_about: 'For the dependent of a Veteran',
        dependent_relationship: nil,
        veteran_relationship: nil,
        level_of_authentication:
      }
    end
    let(:pronouns) do
      { he_him_his: 'true' }
    end
    let(:params) do
      {
        about_yourself: {
          date_of_birth: '1980-05-15',
          first: 'Test',
          last: 'User',
          middle: 'Middle',
          social_or_service_num: { ssn: '123456799' },
          suffix: 'Jr.'
        },
        address: {
          city: 'Los Angeles',
          military_address: {
            military_post_office: 'Army post office',
            military_state: 'Armed Forces Americas (AA)'
          },
          postal_code: '90001',
          state: 'CA',
          street: '123 Main St',
          street2: 'Apt 4B',
          street3: 'Building 5',
          unit_number: 'Unit 10'
        },
        business_email: 'business@example.com',
        business_phone: '123-456-7890',
        country: 'USA',
        email_address: 'test@example.com',
        phone_number: '987-654-3210',
        preferred_name: 'Test User',
        pronouns:,
        school_obj: {
          institution_name: 'University of California',
          school_facility_code: '123456',
          state_abbreviation: 'CA'
        },
        your_location_of_residence: 'California'
      }
    end
    let(:expected_result) do
      {
        FirstName: 'Test',
        MiddleName: 'Middle',
        LastName: 'User',
        PreferredName: 'Test User',
        Suffix: 722_310_000,
        Pronouns: 'he/him/his',
        Country: {
          Name: 'United States',
          CountryCode: 'USA'
        },
        Street: '123 Main St',
        City: 'Los Angeles',
        State: {
          Name: 'California',
          StateCode: 'CA'
        },
        ZipCode: '90001',
        DateOfBirth: '1980-05-15',
        BusinessPhone: nil,
        PersonalPhone: '987-654-3210',
        BusinessEmail: nil,
        PersonalEmail: 'test@example.com',
        SchoolState: 'CA',
        SchoolFacilityCode: '123456',
        SchoolId: nil,
        BranchOfService: nil,
        SSN: '123456799',
        EDIPI: '123',
        ICN: '234',
        ServiceNumber: nil,
        ClaimNumber: nil,
        VeteranServiceStateDate: nil,
        VeteranServiceEndDate: nil
      }
    end

    let(:cache_data_service) { instance_double(Crm::CacheData) }

    before do
      allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
      allow(cache_data_service).to receive(:call).with(
        endpoint: 'optionset',
        cache_key: 'optionset'
      ).and_return(cached_data)
    end

    context 'when PERSONAL inquiry_params is received' do
      it 'builds the correct payload' do
        expect(subject.call).to eq(expected_result)
      end
    end

    context 'when BUSINESS inquiry_params is received' do
      let(:level_of_authentication) { 'Business' }

      it 'builds the correct payload' do
        expect(subject.call[:BusinessPhone]).to eq('987-654-3210')
        expect(subject.call[:BusinessEmail]).to eq('test@example.com')
        expect(subject.call[:PersonalPhone]).to be_nil
        expect(subject.call[:PersonalEmail]).to be_nil
      end
    end

    context 'when pronouns is not listed' do
      let(:pronouns) do
        { pronouns_not_listed_text: 'ze/they' }
      end

      it 'set pronouns to the value' do
        expect(subject.call[:Pronouns]).to eq(pronouns[:pronouns_not_listed_text])
      end
    end
  end
end
