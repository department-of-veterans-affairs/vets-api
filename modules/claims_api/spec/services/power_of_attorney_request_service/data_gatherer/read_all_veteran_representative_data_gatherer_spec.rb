# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::ReadAllVeteranRepresentativeDataGatherer do
  subject { described_class.new(proc_id:, records:) }

  let(:clazz) { described_class }
  let(:proc_id) { '3863961' }
  # partial values returned from this call to keep testing slimmed down
  let(:records) do
    [
      {
        'changeAddressAuth' => 'true',
        'claimantRelationship' => nil,
        'insuranceNumbers' => '1234567890',
        'limitationAlcohol' => 'true',
        'limitationDrugAbuse' => 'true',
        'limitationHIV' => 'true',
        'limitationSCA' => 'true',
        'organizationName' => 'DISABLED AMERICAN VETERANS',
        'phoneNumber' => '5555551234',
        'poaCode' => '083',
        'procId' => '3863961',
        'representativeFirstName' => 'John',
        'representativeLastName' => 'Doe',
        'representativeTitle' => nil,
        'section7332Auth' => 'true',
        'serviceNumber' => '123678453'
      }, {
        'changeAddressAuth' => 'true',
        'claimantRelationship' => nil,
        'insuranceNumbers' => '1234567890',
        'limitationAlcohol' => 'true',
        'limitationDrugAbuse' => 'true',
        'limitationHIV' => 'true',
        'limitationSCA' => 'true',
        'organizationName' => 'DISABLED AMERICAN VETERANS',
        'phoneNumber' => '5555551234',
        'poaCode' => '083',
        'procId' => '3863962',
        'representativeFirstName' => 'John',
        'representativeLastName' => 'Doe',
        'representativeTitle' => nil,
        'section7332Auth' => 'true',
        'serviceNumber' => '123678453'
      }
    ]
  end

  let(:expected_data_obj) do
    {
      'service_number' => '123678453',
      'insurance_numbers' => '1234567890',
      'claimant_relationship' => nil,
      'poa_code' => '083',
      'organization_name' => 'DISABLED AMERICAN VETERANS',
      'representativeLawFirmOrAgencyName' => nil,
      'representative_first_name' => 'John',
      'representative_last_name' => 'Doe',
      'representative_title' => nil,
      'section_7332_auth' => 'true',
      'limitation_alcohol' => 'true',
      'limitation_drug_abuse' => 'true',
      'limitation_hiv' => 'true',
      'limitation_sca' => 'true',
      'change_address_auth' => 'true'
    }
  end

  context 'Mapping the POA data object' do
    it 'gathers the expected data based on the params' do
      allow_any_instance_of(clazz).to receive(:extract_record_by_proc_id).and_return(records.first)

      res = subject.call

      expect(res).to eq(expected_data_obj)
    end

    it 'returns an empty hash when no data is sent' do
      allow_any_instance_of(clazz).to receive(:extract_record_by_proc_id).and_return(nil)

      res = subject.call

      expect(res).to eq({})
    end
  end
end
