# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler do
<<<<<<< HEAD
<<<<<<< HEAD
  subject { described_class.new(proc_id:, poa_code:, registration_number:, metadata:, veteran:, claimant:) }

  let(:clazz) { described_class }
<<<<<<< HEAD
=======
  subject { described_class.new(proc_id:, poa_code:, metadata:, veteran:, claimant:) }

  let(:clazz) { described_class }
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
=======
  subject { described_class.new(proc_id:, poa_code:, representative_id:, metadata:, veteran:, claimant:) }

  let(:clazz) { described_class }
  let(:representative_id) { '12399998' }
>>>>>>> 1255e92ce7 (WIP)
  let(:veteran) do
    OpenStruct.new(
      icn: '1012861229V078999',
      first_name: 'Ralph',
      last_name: 'Lee',
      middle_name: nil,
<<<<<<< HEAD
<<<<<<< HEAD
      birls_id: '796378782',
=======
      file_number: '796378782',
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
=======
      birls_id: '796378782',
>>>>>>> 0f0617637b (Tests veteran and claimant objects matching real records)
      birth_date: '1948-10-30',
      loa: { current: 3, highest: 3 },
      edipi: nil,
      ssn: '796378782',
      participant_id: '600043284',
      mpi: OpenStruct.new(
        icn: '1012861229V078999',
        profile: OpenStruct.new(ssn: '796378782')
      )
    )
  end
<<<<<<< HEAD
  let(:proc_id) { '3864182' }
  let(:poa_code) { '083' }
  let(:registration_number) { '12345678' }

  context 'for a valid decide request' do
    let(:proc_id) { '3864182' }
    let(:poa_code) { '083' }
    let(:claimant) do
      OpenStruct.new(
        icn: '1013093331V548481',
        first_name: 'Wally',
        last_name: 'Morell',
        middle_name: nil,
        birth_date: '1948-10-30',
        loa: { current: 3, highest: 3 },
        edipi: nil,
        ssn: '796378782',
        participant_id: '600264235',
        mpi: OpenStruct.new(
          icn: '1013093331V548481',
          profile: OpenStruct.new(ssn: '796378782'),
          birls_id: '796378782'
        )
      )
    end
    let(:metadata) do
      {
        'veteran' => { 'vnp_mail_id' => '157252', 'vnp_email_id' => '157251', 'vnp_phone_id' => '111641' },
        'claimant' => { 'vnp_mail_id' => '157253', 'vnp_email_id' => '157254', 'vnp_phone_id' => '111642' }
      }
    end

    it 'starts the POA auto establishment service' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler)
        .to receive(:poa_auto_establishment_mapper)

      VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_dependent') do
        subject.call
=======
=======
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)

  context 'Gathering all the required POA data' do
    context 'for a veteran filing' do
      let(:proc_id) { '3864182' }
      let(:poa_code) { '083' }
      let(:claimant) {}
      let(:metadata) do
        { 'veteran' => { 'vnp_phone_id' => '106175', 'vnp_email_id' => '148885', 'vnp_mail_id' => '148886' } }
      end
      let(:expected_veteran_response) do
        {
<<<<<<< HEAD
          name: 'Ralph Lee',
          ssn: '796378782',
          file_number: '796378782',
          date_of_birth: '1948-10-30',
          service_number: '123678453',
          insurance_numbers: '1234567890',
          phone_number: '5555551234',
          claimant_relationship: 'Spouse',
          poa_code: '083',
          organization_name: 'DISABLED AMERICAN VETERANS',
          representativeLawFirmOrAgencyName: nil,
          representative_first_name: 'John',
          representative_last_name: 'Doe',
          representative_title: nil,
          section_7332_auth: 'true',
          limitation_alcohol: 'true',
          limitation_drug_abuse: 'true',
          limitation_hiv: 'true',
          limitation_sca: 'true',
          change_address_auth: 'true',
          addrs_one_txt: '2719 Hyperion Ave',
          addrs_two_txt: 'Apt 2',
          city_nm: 'Los Angeles',
          cntry_nm: 'USA',
          prvnc_nm: nil,
          registration_number: '12399998',
          zip_prefix_nbr: '92264',
          zip_first_suffix_nbr: '0200',
          email_addrs_txt: nil
=======
          'name' => 'Ralph Lee',
          'ssn' => '796378782',
          'file_number' => '796378782',
          'date_of_birth' => '1948-10-30',
          'service_number' => '123678453',
          'insurance_numbers' => '1234567890',
          'phone_number' => '5555551234',
          'claimant_relationship' => 'Spouse',
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
          'change_address_auth' => 'true',
          'addrs_one_txt' => '2719 Hyperion Ave',
          'addrs_two_txt' => 'Apt 2',
          'city_nm' => 'Los Angeles',
          'cntry_nm' => 'USA',
          'prvnc_nm' => nil,
          'zip_prefix_nbr' => '92264',
          'zip_first_suffix_nbr' => '0200',
          'email_addrs_txt' => nil
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
        }
      end

      it 'returns expected data' do
        VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_veteran') do
          res = subject.call

          expect(res).to match(expected_veteran_response)
        end
      end
    end

    context 'for a dependent claimant filing' do
      let(:proc_id) { '3864182' }
      let(:poa_code) { '083' }
      let(:claimant) do
        OpenStruct.new(
          icn: '1013093331V548481',
          first_name: 'Wally',
          last_name: 'Morell',
          middle_name: nil,
          birth_date: '1948-10-30',
          loa: { current: 3, highest: 3 },
          edipi: nil,
          ssn: '796378782',
          participant_id: '600264235',
          mpi: OpenStruct.new(
            icn: '1013093331V548481',
            profile: OpenStruct.new(ssn: '796378782'),
            birls_id: '796378782'
          )
        )
      end
      let(:metadata) do
        {
          'veteran' => { 'vnp_mail_id' => '157252', 'vnp_email_id' => '157251', 'vnp_phone_id' => '111641' },
          'claimant' => { 'vnp_mail_id' => '157253', 'vnp_email_id' => '157254', 'vnp_phone_id' => '111642' }
        }
      end

      let(:expected_dependent_response) do
        {
<<<<<<< HEAD
          name: 'Ralph Lee',
          ssn: '796378782',
          file_number: '796378782',
          date_of_birth: '1948-10-30',
          service_number: '123678453',
          insurance_numbers: '1234567890',
          phone_number: '5555551234',
          claimant_relationship: 'Spouse',
          poa_code: '083',
          organization_name: 'DISABLED AMERICAN VETERANS',
          representativeLawFirmOrAgencyName: nil,
          representative_first_name: 'John',
          representative_last_name: 'Doe',
          representative_title: nil,
          section_7332_auth: 'true',
          limitation_alcohol: 'true',
          limitation_drug_abuse: 'true',
          limitation_hiv: 'true',
          limitation_sca: 'true',
          change_address_auth: 'true',
          addrs_one_txt: '2719 Hyperion Ave',
          addrs_two_txt: 'Apt 2',
          city_nm: 'Los Angeles',
          cntry_nm: 'USA',
          prvnc_nm: nil,
          registration_number: '12399998',
          zip_prefix_nbr: '92264',
          zip_first_suffix_nbr: '0200',
          email_addrs_txt: nil,
          claimant: {
            claimant_id: '1013093331V548481',
            name: 'Wally Morell',
            ssn: '796378782',
            file_number: '796378782',
            date_of_birth: '1948-10-30',
            addrs_one_txt: '123 Main St',
            addrs_two_txt: 'Apt 3',
            city_nm: 'Boston',
            cntry_nm: 'USA',
            prvnc_nm: nil,
            zip_prefix_nbr: '02110',
            zip_first_suffix_nbr: '1000',
            email_addrs_txt: nil,
            phone_nbr: '5555559876'
=======
          'name' => 'Ralph Lee',
          'ssn' => '796378782',
          'file_number' => '796378782',
          'date_of_birth' => '1948-10-30',
          'service_number' => '123678453',
          'insurance_numbers' => '1234567890',
          'phone_number' => '5555551234',
          'claimant_relationship' => 'Spouse',
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
          'change_address_auth' => 'true',
          'addrs_one_txt' => '2719 Hyperion Ave',
          'addrs_two_txt' => 'Apt 2',
          'city_nm' => 'Los Angeles',
          'cntry_nm' => 'USA',
          'prvnc_nm' => nil,
          'zip_prefix_nbr' => '92264',
          'zip_first_suffix_nbr' => '0200',
          'email_addrs_txt' => nil,
          'claimant' => {
            'name' => 'Wally Morell',
            'ssn' => '796378782',
            'file_number' => '796378782',
            'date_of_birth' => '1948-10-30',
            'addrs_one_txt' => '123 Main St',
            'addrs_two_txt' => 'Apt 3',
            'city_nm' => 'Boston',
            'cntry_nm' => 'USA',
            'prvnc_nm' => nil,
            'zip_prefix_nbr' => '02110',
            'zip_first_suffix_nbr' => '1000',
            'email_addrs_txt' => nil,
            'phone_nbr' => '5555559876'
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
          }
        }
      end

      it 'returns expected data' do
        VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_dependent') do
          res = subject.call

          expect(res).to match(expected_dependent_response)
        end
>>>>>>> 265ee2cf48 (API-43735-gather-data-for-poa-accept-phone-3)
      end
    end
  end
end
