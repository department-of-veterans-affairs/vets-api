# frozen_string_literal: true

require 'rails_helper'
require 'bgs/vnp_veteran'

RSpec.describe BGS::VnpVeteran do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }
  let(:formatted_payload) do
    {
      'first' => 'WESLEY',
      'middle' => nil,
      'last' => 'FORD',
      'phone_number' => '1112223333',
      'email_address' => 'foo@foo.com',
      'country_name' => 'USA',
      'address_line1' => '8200 Doby LN',
      'city' => 'Pasadena',
      'state_code' => 'CA',
      'zip_code' => '21122',
      'vet_ind' => 'Y',
      'martl_status_type_cd' => 'Separated',
      'veteran_address' => {
        'country_name' => 'USA',
        'address_line1' => '8200 Doby LN',
        'city' => 'Pasadena',
        'state_code' => 'CA',
        'zip_code' => '21122'
      }
    }
  end

  describe '#create' do
    context 'married veteran' do
      it 'returns a VnpPersonAddressPhone object' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          vnp_veteran = BGS::VnpVeteran.new(proc_id: '3828241', payload: all_flows_payload, user: user_object).create

          expect(vnp_veteran).to eq(
            vnp_participant_id: '149500',
            first_name: 'WESLEY',
            last_name: 'FORD',
            vnp_participant_address_id: '116343',
            file_number: '796043735',
            address_line_one: '8200 Doby LN',
            address_line_two: nil,
            address_line_three: nil,
            address_country: 'USA',
            address_state_code: 'CA',
            address_city: 'Pasadena',
            address_zip_code: '21122',
            type: 'veteran',
            benefit_claim_type_end_product: '134'
          )
        end
      end
    end

    it 'calls BGS::Service: #create_person, #create_phone, and #create_address' do
      vet_person_hash = {
        vnp_proc_id: '12345',
        vnp_ptcpnt_id: '149500',
        first_nm: 'WESLEY',
        middle_nm: nil,
        last_nm: 'FORD',
        suffix_nm: nil,
        birth_state_cd: nil,
        birth_city_nm: nil,
        file_nbr: '796043735',
        ssn_nbr: '796043735',
        death_dt: nil,
        ever_maried_ind: nil,
        vet_ind: 'Y',
        martl_status_type_cd: 'Separated'
      }

      expected_address = {
        addrs_one_txt: '8200 Doby LN',
        addrs_three_txt: nil,
        addrs_two_txt: nil,
        city_nm: 'Pasadena',
        cntry_nm: 'USA',
        email_addrs_txt: 'foo@foo.com',
        mlty_post_office_type_cd: nil,
        mlty_postal_type_cd: nil,
        postal_cd: 'CA',
        prvnc_nm: 'CA',
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        vnp_proc_id: '12345',
        vnp_ptcpnt_id: '149500',
        zip_prefix_nbr: '21122'
      }
      VCR.use_cassette('bgs/vnp_veteran/create') do
        expect_any_instance_of(BGS::Service).to receive(:create_person)
          .with(a_hash_including(vet_person_hash))
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_phone)
          .with(anything, anything, a_hash_including(formatted_payload))
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_address)
          .with(a_hash_including(expected_address))
          .and_call_original

        BGS::VnpVeteran.new(proc_id: '12345', payload: all_flows_payload, user: user_object).create
      end
    end
  end
end
