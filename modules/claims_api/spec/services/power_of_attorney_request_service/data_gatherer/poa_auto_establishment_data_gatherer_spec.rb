# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::PoaAutoEstablishmentDataGatherer do
  subject { described_class.new(proc_id:, registration_number:, metadata:, veteran:, claimant:) }

  let(:veteran) do
    OpenStruct.new(
      icn: '1012667169V030190',
      first_name: 'Ralph',
      last_name: 'Lee',
      middle_name: nil,
      birls_id: '796378782',
      birth_date: '1948-10-30',
      loa: { current: 3, highest: 3 },
      edipi: nil,
      ssn: '796378782',
      participant_id: '600045025',
      mpi: OpenStruct.new(
        icn: '1012667169V030190',
        profile: OpenStruct.new(ssn: '796378782')
      )
    )
  end
  let(:proc_id) { '3864476' }
  let(:registration_number) { '12345678' }
  let(:metadata) do
    {
      'veteran' => { 'vnp_mail_id' => '157252', 'vnp_email_id' => '157251', 'vnp_phone_id' => '111641' },
      'claimant' => { 'vnp_mail_id' => '157253', 'vnp_email_id' => '157254', 'vnp_phone_id' => '111642' }
    }
  end
  let(:claimant) { nil }
  let(:gathered_data_obj) do
    {
      'service_number' => nil, 'insurance_numbers' => nil, 'phone_number' => '5555551234',
      'claimant_relationship' => nil, 'poa_code' => '074', 'organization_name' => 'AMERICAN LEGION',
      'representativeLawFirmOrAgencyName' => nil, 'representative_first_name' => 'John',
      'representative_last_name' => 'Doe', 'representative_title' => nil, 'section_7332_auth' => 'true',
      'limitation_alcohol' => 'false', 'limitation_drug_abuse' => 'false', 'limitation_hiv' => 'false',
      'limitation_sca' => 'false', 'change_address_auth' => 'true', 'addrs_one_txt' => '2719 Hyperion Ave',
      'addrs_two_txt' => 'Apt 2', 'city_nm' => 'Los Angeles', 'cntry_nm' => 'USA', 'postal_cd' => 'CA',
      'zip_prefix_nbr' => '92264', 'zip_first_suffix_nbr' => '0200', 'email_addrs_txt' => nil,
      'registration_number' => '12345678'
    }
  end

  let(:gathered_data_obj_with_claimant) do
    {
      'addrs_one_txt' => '2719 Hyperion Ave', 'addrs_two_txt' => 'Apt 2', 'city_nm' => 'Los Angeles',
      'cntry_nm' => 'USA', 'postal_cd' => 'CA', 'zip_prefix_nbr' => '92264', 'zip_first_suffix_nbr' => '0200',
      'email_addrs_txt' => nil, 'registration_number' => '12345678',
      'claimant' => { 'addrs_one_txt' => '123 Main St', 'addrs_two_txt' => 'Apt 3',
                      'city_nm' => 'Boston', 'cntry_nm' => 'USA', 'postal_cd' => 'MA', 'zip_prefix_nbr' => '02110',
                      'zip_first_suffix_nbr' => '1000', 'email_addrs_txt' => nil, 'phone_nbr' => '5555559876',
                      'claimant_id' => '1013093331V548481' }
    }
  end

  context 'veteran request' do
    it 'returns the expect data object for a veteran request' do
      VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/data_gatherer/poa_data_gather') do
        res = subject.gather_data

        expect(res).to eq(gathered_data_obj)
      end
    end
  end

  context 'request with claimant' do
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
    let(:proc_id) { '3864478' }
    let(:metadata) do
      {
        'veteran' => { 'vnp_mail_id' => '157653', 'vnp_email_id' => '157652', 'vnp_phone_id' => '111989' },
        'claimant' => { 'vnp_mail_id' => '157655', 'vnp_email_id' => '157654', 'vnp_phone_id' => '111990' }
      }
    end

    it 'returns the expect data object for a veteran request with claimant' do
      VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/data_gatherer/poa_data_gather_dependent') do
        res = subject.gather_data

        expect(res).to eq(gathered_data_obj_with_claimant)
      end
    end

    describe '#vnp_phone_data' do
      let(:proc_id) { '3865028' }
      let(:registration_number) { '23456789' }
      let(:metadata) do
        {
          'veteran' => { 'vnp_mail_id' => '158304', 'vnp_email_id' => '158305', 'vnp_phone_id' => '112509' },
          'claimant' => { 'vnp_mail_id' => '158306', 'vnp_email_id' => '158307' }
        }
      end

      it 'does not call BGS if no phone number was submitted for the claimant' do
        expect_any_instance_of(described_class).not_to receive(:gather_vnp_phone_data)
        cassette = 'poa_data_gather_dependent_no_phone'

        VCR.use_cassette("claims_api/power_of_attorney_request_service/decide/data_gatherer/#{cassette}") do
          subject.gather_data
        end
      end
    end
  end
end
