# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::Dependents do
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
      # VCR.use_cassette('bgs/dependents/create') do
      #   dependents = BGS::Dependents.new(proc_id: '12345', payload: payload, veteran: user, user: user).create
      #
      #   expect(dependents).to include(an_object_having_attributes(foo: 'bar', baz: 'boiz'))
      # end
    end

    context 'adding children'
    context 'reporting a death'
    context 'adding a spouse'
    context 'reporting a divorce'
  end
end
