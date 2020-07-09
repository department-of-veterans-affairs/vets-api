# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::VnpVeteran do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:fixtures_path) { "#{Rails.root}/spec/fixtures/686c/dependents" }
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
      'veteran_address' => { 'country_name' => 'USA', 'address_line1' => '8200 Doby LN', 'city' => 'Pasadena', 'state_code' => 'CA', 'zip_code' => '21122' },
      'phone_number' => '1112223333',
      'email_address' => 'foo@foo.com',
      'country_name' => 'USA',
      'address_line1' => '8200 Doby LN',
      'city' => 'Pasadena',
      'state_code' => 'CA',
      'zip_code' => '21122',
      'vet_ind' => 'Y',
      'martl_status_type_cd' => 'OTHER'
    }
  end

  describe '#create' do
    context 'married veteran' do
      it 'returns a VnpPersonAddressPhone object' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          vnp_veteran = BGS::VnpVeteran.new(proc_id: '3828241', payload: all_flows_payload, user: user).create

          expect(vnp_veteran).to eq(
            vnp_participant_id: '149000',
            first_name: 'WESLEY',
            last_name: 'FORD',
            vnp_participant_address_id: '115983',
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

    it 'calls BGS::Base: #create_person, #create_phone, and #create_address' do
      VCR.use_cassette('bgs/vnp_veteran/create') do
        expect_any_instance_of(BGS::Base).to receive(:create_person)
          .with('12345', '149000', formatted_payload)
          .and_call_original

        expect_any_instance_of(BGS::Base).to receive(:create_phone)
          .with('12345', '149000', formatted_payload)
          .and_call_original

        expect_any_instance_of(BGS::Base).to receive(:create_address)
          .with('12345', '149000', formatted_payload)
          .and_call_original

        BGS::VnpVeteran.new(proc_id: '12345', payload: all_flows_payload, user: user).create
      end
    end
  end
end
