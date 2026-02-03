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
      'veteran' => { 'vnp_mail_id' => '157252', 'vnp_email_id' => '157251', 'vnp_phone_id' => '111641',
                     'phone_data' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '5551234' } },
      'claimant' => { 'vnp_mail_id' => '157253', 'vnp_email_id' => '157254', 'vnp_phone_id' => '111642',
                      'phone_data' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '9876543' } }
    }
  end
  let(:claimant) { nil }
  let(:gathered_data_obj) do
    {
      'service_number' => nil, 'insurance_numbers' => nil, 'country_code' => '1', 'area_code' => '555',
      'phone_number' => '5551234', 'claimant_relationship' => nil, 'poa_code' => '074',
      'organization_name' => 'AMERICAN LEGION', 'representativeLawFirmOrAgencyName' => nil,
      'representative_first_name' => 'John', 'representative_last_name' => 'Doe', 'representative_title' => nil,
      'section_7332_auth' => 'true', 'limitation_alcohol' => 'false', 'limitation_drug_abuse' => 'false',
      'limitation_hiv' => 'false', 'limitation_sca' => 'false', 'change_address_auth' => 'true',
      'addrs_one_txt' => '2719 Hyperion Ave', 'addrs_two_txt' => 'Apt 2', 'city_nm' => 'Los Angeles',
      'cntry_nm' => 'USA', 'postal_cd' => 'CA', 'zip_prefix_nbr' => '92264', 'zip_first_suffix_nbr' => '0200',
      'email_addrs_txt' => nil, 'registration_number' => '12345678'
    }
  end

  let(:gathered_data_obj_with_claimant) do
    {
      'service_number' => '123678453', 'insurance_numbers' => '1234567890', 'claimant_relationship' => 'Spouse',
      'poa_code' => '083', 'organization_name' => 'DISABLED AMERICAN VETERANS',
      'representativeLawFirmOrAgencyName' => nil, 'representative_first_name' => 'John',
      'representative_last_name' => 'Doe', 'representative_title' => nil,
      'section_7332_auth' => 'true', 'limitation_alcohol' => 'true', 'limitation_drug_abuse' => 'true',
      'limitation_hiv' => 'true', 'limitation_sca' => 'true', 'change_address_auth' => 'true',
      'addrs_one_txt' => '2719 Pluto Ave', 'addrs_two_txt' => 'Apt 2', 'city_nm' => 'Los Angeles',
      'cntry_nm' => 'Vietnam', 'postal_cd' => 'CA', 'zip_prefix_nbr' => '92264', 'zip_first_suffix_nbr' => '0200',
      'email_addrs_txt' => nil, 'registration_number' => '12345678', 'country_code' => '1', 'area_code' => '555',
      'phone_number' => '5551234', 'claimant' => {
        'addrs_one_txt' => '123 Main St', 'addrs_two_txt' => 'Apt 3', 'city_nm' => 'Boston', 'cntry_nm' => 'USA',
        'postal_cd' => 'MA', 'zip_prefix_nbr' => '02110', 'zip_first_suffix_nbr' => '1000', 'email_addrs_txt' => nil,
        'country_code' => '1', 'area_code' => '555', 'phone_number' => '5559876', 'claimant_id' => '1013093331V548481'
      }
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
        'veteran' => { 'vnp_mail_id' => '157653', 'vnp_email_id' => '157652', 'vnp_phone_id' => '111989',
                       'phone_data' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '5551234' } },
        'claimant' => { 'vnp_mail_id' => '157655', 'vnp_email_id' => '157654', 'vnp_phone_id' => '111990',
                        'phone_data' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '5559876' } }
      }
    end

    it 'returns the expect data object for a veteran request with claimant' do
      VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/data_gatherer/poa_data_gather_dependent') do
        res = subject.gather_data

        expect(res).to eq(gathered_data_obj_with_claimant)
      end
    end
  end

  describe '#validate_phone_data' do
    let(:metadata) do
      {
        'veteran' => {
          'vnp_mail_id' => '157252',
          'vnp_email_id' => '157251',
          'vnp_phone_id' => '111641',
          'phone_data' => {
            'countryCode' => '1',
            'areaCode' => '555',
            'phoneNumber' => '5551234'
          }
        }
      }
    end

    context 'when phone data matches' do
      let(:fetched_data) { { 'phone_nbr' => '5555551234' } }

      it 'does not raise an error' do
        res = subject.send(:validate_phone_data, fetched_data['phone_nbr'], 'veteran')

        expect(res).to be_nil
      end
    end

    context 'when phone data does not match' do
      let(:fetched_data) { { 'phone_nbr' => '5559999999' } }

      it 'raises an UnprocessableEntity error' do
        expect { subject.send(:validate_phone_data, fetched_data['phone_nbr'], 'veteran') }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity,
                          /Phone data mismatch for veteran/)
      end
    end

    context 'for claimant' do
      let(:metadata) do
        {
          'veteran' => { 'vnp_mail_id' => '157252' },
          'claimant' => {
            'vnp_phone_id' => '111642',
            'phone_data' => {
              'countryCode' => '1',
              'areaCode' => '555',
              'phoneNumber' => '9876543'
            }
          }
        }
      end
      let(:fetched_data) { { 'phone_nbr' => '5559876543' } }

      it 'validates claimant phone data correctly' do
        res = subject.send(:validate_phone_data, fetched_data['phone_nbr'], 'claimant')

        expect(res).to be_nil
      end
    end

    context 'backwards compatibility' do
      let(:metadata) do
        {
          'veteran' => {
            'vnp_mail_id' => '157252',
            'vnp_email_id' => '157251',
            'vnp_phone_id' => '111641'
          }
        }
      end

      let(:fetched_data) { { 'phone_nbr' => '5555551234' } }
      let(:expected_empty_response) { { 'country_code' => nil, 'area_code' => nil, 'phone_number' => nil } }
      let(:expected_parsed_response) { { 'country_code' => nil, 'area_code' => '555', 'phone_number' => '5551234' } }

      context 'when a vnp_phone_id is present but no phone_data in the metadata' do
        it 'returns the phone number from the vnp phone look up' do
          VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/data_gatherer/poa_data_gather') do
            res = subject.send(:gather_vnp_phone_data, 'veteran')

            expect(res).to eq(expected_parsed_response)
          end
        end
      end

      context 'when phone_data is missing in metadata and BGS returns nil phone number' do
        it 'returns fetched data without calling parse_phone_number' do
          allow_any_instance_of(ClaimsApi::VnpPtcpntPhoneService)
            .to receive(:vnp_ptcpnt_phone_find_by_primary_key).and_return({ phone_nbr: nil })

          result = subject.send(:gather_vnp_phone_data, 'veteran')

          expect(result).to eq(expected_empty_response)
        end
      end

      context 'when phone_data is missing in metadata and BGS returns empty string' do
        it 'returns fetched data without calling parse_phone_number' do
          allow_any_instance_of(ClaimsApi::VnpPtcpntPhoneService)
            .to receive(:vnp_ptcpnt_phone_find_by_primary_key).and_return({ phone_nbr: '' })

          result = subject.send(:gather_vnp_phone_data, 'veteran')

          expect(result).to eq(expected_empty_response)
        end
      end
    end
  end
end
