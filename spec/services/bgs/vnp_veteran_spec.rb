# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::VnpVeteran do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:payload) do
    {
      'first' => 'Vet First Name',
      'last' => 'Vet Last Name',
      'middle' => 'Vet Middle Name',
      'veteran_address' => {
        'view:livesOnMilitaryBase' => false,
        'view:livesOnMilitaryBaseInfo' => {},
        'country_name' => 'United States',
        'address_line1' => '1019 Robin Cir',
        'address_line2' => 'NA',
        'address_line3' => 'NA',
        'city' => 'Arroyo Grande',
        'state_code' => 'CA',
        'zip_code' => '93420'
      },
      'veteran_information' => {
        'first' => 'Adam',
        'middle' => 'billy',
        'last' => 'Huberws',
        'suffix' => 'Jr.',
        'ssn' => '370947141',
        'va_file_number' => '370947141',
        'service_number' => '12345678',
        'birth_date' => '1982-02-04'
      },
      'more_veteran_information' => {
        'phone_number' => '2146866521',
        'email_address' => 'cohnjesse@gmail.xom'
      },
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
      "first" => "Adam",
      "middle" => "billy",
      "last" => "Huberws",
      "suffix" => "Jr.",
      "ssn" => "370947141",
      "va_file_number" => "370947141",
      "service_number" => "12345678",
      "birth_date" => "1982-02-04",
      "phone_number" => "2146866521",
      "email_address" => "cohnjesse@gmail.xom",
      "view:livesOnMilitaryBase" => false,
      "view:livesOnMilitaryBaseInfo" => {},
      "country_name" => "United States",
      "address_line1" => "1019 Robin Cir",
      "address_line2" => "NA",
      "address_line3" => "NA",
      "city" => "Arroyo Grande",
      "state_code" => "CA",
      "zip_code" => "93420",
      "vet_ind" => "Y",
      "martl_status_type_cd" => "OTHER"
    }
  end

  describe '#create' do
    it 'returns a VnpPersonAddressPhone object' do
      VCR.use_cassette('bgs/vnp_veteran/create') do
        vnp_veteran = BGS::VnpVeteran.new(proc_id: '12345', payload: payload, user: user).create

        expect(vnp_veteran).to have_attributes(
                                 address_city: 'Arroyo Grande',
                                 participant_relationship_type_name: 'Veteran',
                                 phone_number: '2146866521',
                                 first_name: 'Adam'
                               )
      end
    end

    it 'calls BGS::Base: #create_person, #create_phone, and #create_address' do
      VCR.use_cassette('bgs/vnp_veteran/create') do
        expect_any_instance_of(BGS::Base).to receive(:create_person)
                                               .with('12345', '146265', formatted_payload)
                                              .and_call_original

        expect_any_instance_of(BGS::Base).to receive(:create_phone)
                                               .with('12345', '146265', formatted_payload)
                                               .and_call_original

        expect_any_instance_of(BGS::Base).to receive(:create_address)
                                               .with('12345', '146265', formatted_payload)
                                               .and_call_original

        BGS::VnpVeteran.new(proc_id: '12345', payload: payload, user: user).create
      end
    end
  end
end
