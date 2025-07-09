# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::ReadAllVeteranRepresentativeDataMapper do
  subject { described_class.new(proc_id:, records:) }

  let(:clazz) { described_class }
  let(:proc_id) { '3863961' }
  let(:records) do
    [
      {
        'addressLine1' => '2719 Atlas Ave',
        'addressLine2' => 'Apt 2',
        'addressLine3' => nil,
        'changeAddressAuth' => 'true',
        'city' => 'Los Angeles',
        'claimantRelationship' => nil,
        'formTypeCode' => '21-22',
        'insuranceNumbers' => '1234567890',
        'limitationAlcohol' => 'true',
        'limitationDrugAbuse' => 'true',
        'limitationHIV' => 'true',
        'limitationSCA' => 'true',
        'organizationName' => 'DISABLED AMERICAN VETERANS',
        'otherServiceBranch' => nil,
        'phoneNumber' => '5555551234',
        'poaCode' => '083',
        'postalCode' => '92264',
        'procId' => '3863961',
        'representativeFirstName' => 'John',
        'representativeLastName' => 'Doe',
        'representativeLawFirmOrAgencyName' => nil,
        'representativeTitle' => nil,
        'representativeType' => 'Recognized Veterans Service Organization',
        'section7332Auth' => 'true',
        'serviceBranch' => 'Marine Corps',
        'serviceNumber' => '123678453',
        'state' => 'CA',
        'submittedDate' => '2025-07-08T16:05:12-05:00',
        'vdcStatus' => 'Submitted',
        'veteranPtcpntId' => '196002',
        'acceptedBy' => nil,
        'claimantFirstName' => nil,
        'claimantLastName' => nil,
        'claimantMiddleName' => nil,
        'declinedBy' => nil,
        'declinedReason' => nil,
        'secondaryStatus' => 'New',
        'veteranFirstName' => 'RALPH',
        'veteranLastName' => 'LEE',
        'veteranMiddleName' => nil,
        'veteranSSN' => '796378782',
        'veteranVAFileNumber' => '00123456'
      }, {
        'addressLine1' => '2719 Atlas Ave',
        'addressLine2' => 'Apt 2',
        'addressLine3' => nil,
        'changeAddressAuth' => 'true',
        'city' => 'Los Angeles',
        'claimantRelationship' => nil,
        'formTypeCode' => '21-22',
        'insuranceNumbers' => '1234567890',
        'limitationAlcohol' => 'true',
        'limitationDrugAbuse' => 'true',
        'limitationHIV' => 'true',
        'limitationSCA' => 'true',
        'organizationName' => 'DISABLED AMERICAN VETERANS',
        'otherServiceBranch' => nil,
        'phoneNumber' => '5555551234',
        'poaCode' => '083',
        'postalCode' => '92264',
        'procId' => '3863962',
        'representativeFirstName' => 'John',
        'representativeLastName' => 'Doe',
        'representativeLawFirmOrAgencyName' => nil,
        'representativeTitle' => nil,
        'representativeType' => 'Recognized Veterans Service Organization',
        'section7332Auth' => 'true',
        'serviceBranch' => 'Marine Corps',
        'serviceNumber' => '123678453',
        'state' => 'CA',
        'submittedDate' => '2025-07-08T16:05:58-05:00',
        'vdcStatus' => 'Submitted',
        'veteranPtcpntId' => '196004',
        'acceptedBy' => nil,
        'claimantFirstName' => nil,
        'claimantLastName' => nil,
        'claimantMiddleName' => nil,
        'declinedBy' => nil,
        'declinedReason' => nil,
        'secondaryStatus' => 'New',
        'veteranFirstName' => 'RALPH',
        'veteranLastName' => 'LEE',
        'veteranMiddleName' => nil,
        'veteranSSN' => '796378782',
        'veteranVAFileNumber' => '00123456'
      }
    ]
  end

  let(:expected_data_obj) do
    {
      service_number: '123678453',
      insurance_numbers: '1234567890',
      phone_number: '5555551234',
      claimant_relationship: nil,
      poa_code: '083',
      organization_name: 'DISABLED AMERICAN VETERANS',
      representative_first_name: 'John',
      representative_last_name: 'Doe',
      representative_title: nil,
      section_7332_auth: 'true',
      limitation_alcohol: 'true',
      limitation_drug_abuse: 'true',
      limitation_hiv: 'true',
      limitation_sca: 'true',
      change_address_auth: 'true'
    }
  end

  context 'Mapping the POA data object' do
    it 'gathers the expected data based on the params' do
      allow_any_instance_of(clazz).to receive(:extract_record_by_proc_id).and_return(records.first)

      res = subject.call

      expect(res).to eq(expected_data_obj)
    end

    it 'returns an empty array when no data is sent' do
      allow_any_instance_of(clazz).to receive(:extract_record_by_proc_id).and_return(nil)

      res = subject.call

      expect(res).to eq([])
    end
  end
end
