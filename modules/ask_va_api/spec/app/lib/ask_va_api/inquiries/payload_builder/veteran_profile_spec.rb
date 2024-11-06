# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::PayloadBuilder::VeteranProfile do
  describe '#call' do
    subject(:builder) { described_class.new(inquiry_params: params, inquiry_details:) }

    let(:cached_data) do
      data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
      JSON.parse(data, symbolize_names: true)
    end
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
        veteran_postal_code: '54321',
        veterans_location_of_residence: 'Texas'
      }
    end
    let(:level_of_authentication) { 'Personal' }
    let(:inquiry_details) do
      {
        inquiry_about: 'For the dependent of a Veteran',
        dependent_relationship: nil,
        veteran_relationship: nil,
        level_of_authentication: level_of_authentication
      }
    end
    let(:expected_result) do
      { FirstName: params[:about_the_veteran][:first],
        MiddleName: params[:about_the_veteran][:middle],
        LastName: params[:about_the_veteran][:last],
        PreferredName: params[:about_the_veteran][:preferred_name],
        Suffix: 722_310_001,
        Country: nil,
        Street: nil,
        City: nil,
        State: { Name: 'Texas', StateCode: 'TX' },
        ZipCode: params[:veteran_postal_code],
        DateOfBirth: params[:about_the_veteran][:date_of_birth],
        BranchOfService: params[:about_the_veteran][:branch_of_service],
        SSN: params[:about_the_veteran][:social_or_service_num][:ssn],
        ServiceNumber: params[:about_the_veteran][:social_or_service_num][:service_number],
        ClaimNumber: nil,
        VeteranServiceStateDate: nil,
        VeteranServiceEndDate: nil }
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
  end
end
