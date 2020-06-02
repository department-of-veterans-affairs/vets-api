# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::VnpVeteran do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:payload) do
    root = Rails.root.to_s
    f = File.read("#{root}/spec/services/bgs/support/final_payload.json")
    JSON.parse(f)
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
    {"full_name" => {"first" => "Mark", "middle" => "billy", "last" => "Webb", "suffix" => "Jr."},
     "ssn" => "796104437",
     "va_file_number" => "796104437",
     "service_number" => "12345678",
     "birth_date" => "1950-10-04",
     "first" => "Mark",
     "middle" => "billy",
     "last" => "Webb",
     "suffix" => "Jr.",
     "veteran_address" => {"country_name" => "USA", "address_line1" => "8200 DOBY LN", "city" => "PASADENA", "state_code" => "CA", "zip_code" => "21122"},
     "phone_number" => "1112223333",
     "email_address" => "vets.gov.user+228@gmail.com",
     "country_name" => "USA",
     "address_line1" => "8200 DOBY LN",
     "city" => "PASADENA",
     "state_code" => "CA",
     "zip_code" => "21122",
     "vet_ind" => "Y",
     "martl_status_type_cd" => "OTHER"}
  end

  describe '#create' do
    context 'married veteran' do
      it 'returns a VnpPersonAddressPhone object' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          vnp_veteran = BGS::VnpVeteran.new(proc_id: '3828241', payload: payload, user: user).create

          expect(vnp_veteran).to have_attributes(
                                   address_city: 'PASADENA',
                                   participant_relationship_type_name: 'Veteran',
                                   phone_number: '1112223333',
                                   first_name: 'Mark',
                                   ssn_number: '796104437',
                                   email_address: "vets.gov.user+228@gmail.com",
                                   file_number: "796104437"
                                 )
        end
      end
    end

    it 'calls BGS::Base: #create_person, #create_phone, and #create_address' do
      VCR.use_cassette('bgs/vnp_veteran/create') do
        expect_any_instance_of(BGS::Base).to receive(:create_person)
                                               .with('12345', '146793', formatted_payload)
                                               .and_call_original

        expect_any_instance_of(BGS::Base).to receive(:create_phone)
                                               .with('12345', '146793', formatted_payload)
                                               .and_call_original

        expect_any_instance_of(BGS::Base).to receive(:create_address)
                                               .with('12345', '146793', formatted_payload)
                                               .and_call_original

        BGS::VnpVeteran.new(proc_id: '12345', payload: payload, user: user).create
      end
    end
  end
end
