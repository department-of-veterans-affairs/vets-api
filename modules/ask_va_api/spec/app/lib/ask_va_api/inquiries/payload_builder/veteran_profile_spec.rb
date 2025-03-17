# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::PayloadBuilder::VeteranProfile do
  describe '#call' do
    subject(:builder) { described_class.new(inquiry_params: params, user: authorized_user, inquiry_details:) }

    let(:authorized_user) { build(:user, :accountable_with_sec_id, icn: '234', edipi: '123') }
    let(:cached_data) do
      data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
      JSON.parse(data, symbolize_names: true)
    end

    let(:cache_data_service) { instance_double(Crm::CacheData) }

    before do
      allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
      allow(cache_data_service).to receive(:call).with(
        endpoint: 'optionset',
        cache_key: 'optionset'
      ).and_return(cached_data)
    end

    context 'when the submitter is not the veteran' do
      let(:params) do
        {
          about_the_veteran: {
            branch_of_service: 'Army',
            date_of_birth: '1950-06-20',
            first: 'Joseph',
            last: 'Name',
            middle: 'Middle',
            preferred_name: 'Joe',
            social_or_service_num: {
              service_number: 'A1234567',
              ssn: '987654321'
            },
            suffix: 'Sr.'
          },
          veterans_postal_code: '54321',
          veterans_location_of_residence: 'Texas'
        }
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
      let(:expected_result) do
        { FirstName: params[:about_the_veteran][:first],
          MiddleName: params[:about_the_veteran][:middle],
          LastName: params[:about_the_veteran][:last],
          PreferredName: params[:about_the_veteran][:preferred_name],
          Suffix: 722_310_001,
          Country: { Name: nil, CountryCode: nil },
          Street: nil,
          City: nil,
          State: { Name: 'Texas', StateCode: 'TX' },
          ZipCode: params[:veterans_postal_code],
          DateOfBirth: params[:about_the_veteran][:date_of_birth],
          BranchOfService: params[:about_the_veteran][:branch_of_service],
          SSN: params[:about_the_veteran][:social_or_service_num][:ssn],
          EDIPI: nil,
          ICN: nil,
          ServiceNumber: params[:about_the_veteran][:social_or_service_num][:service_number] }
      end

      context 'when PERSONAL inquiry_params is received' do
        it 'builds the correct payload' do
          expect(subject.call).to eq(expected_result)
        end
      end
    end

    context 'when the submitter IS the veteran' do
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
          relationship_to_veteran: "I'm the Veteran",
          business_email: 'business@example.com',
          business_phone: '123-456-7890',
          country: 'USA',
          email_address: 'test@example.com',
          phone_number: '987-654-3210',
          preferred_name: 'Test User',
          school_obj: {
            institution_name: 'University of California',
            school_facility_code: '123456',
            state_abbreviation: 'CA'
          },
          your_location_of_residence: 'California'
        }
      end
      let(:level_of_authentication) { 'Personal' }
      let(:inquiry_details) do
        {
          inquiry_about: 'About Me, the Veteran',
          dependent_relationship: nil,
          veteran_relationship: nil,
          level_of_authentication:
        }
      end
      let(:expected_result) do
        {
          FirstName: 'Test',
          MiddleName: 'Middle',
          LastName: 'User',
          PreferredName: 'Test User',
          Suffix: 722_310_000,
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
          ServiceNumber: nil
        }
      end

      it 'duplicates submitter profile and veteran profile' do
        expect(subject.call).to eq(expected_result)
      end
    end

    context 'when form is a general question' do
      let(:inquiry_details) do
        {
          inquiry_about: 'A general question',
          dependent_relationship: nil,
          veteran_relationship: nil,
          level_of_authentication: 'Personal'
        }
      end
      let(:params) do
        {
          category_id: '73524deb-d864-eb11-bb24-000d3a579c45',
          email_address: 'test@test.com',
          on_base_outside_us: false,
          phone_number: '3039751100',
          question: 'test',
          select_category: 'Health care',
          select_topic: 'Audiology and hearing aids',
          subtopic_id: '',
          topic_id: 'c0da1728-d91f-ed11-b83c-001dd8069009',
          who_is_your_question_about: "It's a general question",
          your_health_facility: 'vba_349b',
          address: { military_address: {} },
          about_yourself: {
            first: 'Yourself',
            last: 'test',
            social_or_service_num: {},
            suffix: 'Jr.'
          },
          about_the_veteran: { social_or_service_num: {} },
          about_the_family_member: { social_or_service_num: {} },
          state_or_residency: {},
          files: [{ file_name: nil, file_content: nil }],
          school_obj: {}
        }
      end
      let(:expected_result) do
        { FirstName: nil,
          MiddleName: nil,
          LastName: nil,
          PreferredName: nil,
          Suffix: nil,
          Country: { Name: nil, CountryCode: nil },
          Street: nil,
          City: nil,
          State: { Name: nil, StateCode: nil },
          ZipCode: nil,
          DateOfBirth: nil }
      end

      it 'returns the correct payload' do
        expect(subject.call).to eq(expected_result)
      end
    end
  end
end
