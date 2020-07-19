# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::VnpVeteran do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:user_hash) do
    {
      participant_id: user_object.participant_id,
      ssn: user_object.ssn,
      first_name: user_object.first_name,
      last_name: user_object.last_name,
      external_key: user_object.common_name || user_object.email,
      icn: user_object.icn
    }
  end
  let(:fixtures_path) { Rails.root.join('spec', 'fixtures', '686c', 'dependents') }
  let(:all_flows_payload) do
    payload = File.read("#{fixtures_path}/all_flows_payload.json")
    JSON.parse(payload)
  end
  let(:current_marriage_details) do
    {
      'current_marriage_details' => {
        'date_of_marriage' => '2014-03-04',
        'location_of_marriage' => {
          'state' => 'California',
          'city' => 'Slawson'
        },
        'marriage_type' => 'OTHER',
        'marriage_type_other' => 'Some Other type',
        'view:marriageTypeInformation' => {}
      }
    }
  end
  let(:formatted_payload) do # This is here for the mocks since they receive formatted params
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
      'martl_status_type_cd' => 'OTHER',
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
          vnp_veteran = BGS::VnpVeteran.new(proc_id: '3828241', payload: all_flows_payload, user: user_hash).create

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
      VCR.use_cassette('bgs/vnp_veteran/create') do
        expect_any_instance_of(BGS::Service).to receive(:create_person)
          .with(anything, anything, formatted_payload)
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_phone)
          .with(anything, anything, formatted_payload)
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_address)
          .with(anything, anything, formatted_payload)
          .and_call_original

        BGS::VnpVeteran.new(proc_id: '12345', payload: all_flows_payload, user: user_hash).create
      end
    end
  end
end
