# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_fes_mapper'

describe ClaimsApi::V2::DisabilityCompensationFesMapper do
  describe '526 claim maps to FES format' do
    context 'with v1 form data' do
      let(:form_data) do
        JSON.parse(
          Rails.root.join(
            'modules',
            'claims_api',
            'spec',
            'fixtures',
            'form_526_json_api.json'
          ).read
        )
      end
      let(:auto_claim) do
        create(:auto_established_claim,
               form_data: form_data['data']['attributes'],
               auth_headers: { 'va_eauth_pid' => '600061742' })
      end
      let(:fes_data) do
        ClaimsApi::V2::DisabilityCompensationFesMapper.new(auto_claim).map_claim
      end

      it 'maps v1 veteran data to FES format' do
        expect(fes_data).to have_key(:data)
        expect(fes_data[:data]).to have_key(:form526)
        expect(fes_data[:data][:form526]).to have_key(:veteran)
      end

      it 'maps v1 address correctly' do
        address = fes_data[:data][:form526][:veteran][:currentMailingAddress]
        expect(address).to include(
          addressLine1: '1234 Couch Street',
          city: 'Portland',
          state: 'OR',
          country: 'USA',
          zipFirstFive: '12345',
          addressType: 'DOMESTIC'
        )
      end

      it 'handles v1 disabilities structure' do
        disabilities = fes_data[:data][:form526][:disabilities]
        expect(disabilities).to be_an(Array)
        expect(disabilities).not_to be_empty
      end

      it 'handles v1 service information' do
        service_info = fes_data[:data][:form526][:serviceInformation]
        expect(service_info).to be_present
        expect(service_info[:servicePeriods]).to be_an(Array)
      end
    end
  end
end
