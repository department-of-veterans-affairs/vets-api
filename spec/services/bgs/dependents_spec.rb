# frozen_string_literal: true

require 'rails_helper'
require 'bgs/value_objects/vnp_person_address_phone'

RSpec.describe BGS::Dependents do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:payload) do
    {
      'children_to_add' => [
        {
          'does_child_live_with_you' => false,
          'child_address_info' => {
            'person_child_lives_with' => {
              'first' => 'Bill',
              'middle' => 'Oliver',
              'last' => 'Bradsky'
            },
            'child_address' => {
              'country_name' => 'United States',
              'address_line1' => '1019 Robin Cir',
              'address_line2' => 'NA',
              'address_line3' => 'NA',
              'city' => 'Arroyo Grande',
              'state_code' => 'CA',
              'zip_code' => '93420'
            }
          },
          'child_place_of_birth' => {
            'state' => 'California',
            'city' => 'Slawson'
          },
          'child_status' => {
            'biological' => true
          },
          'view:childStatusInformation' => {},
          'child_previously_married' => 'Yes',
          'child_previous_marriage_details' => {
            'date_marriage_ended' => '2018-03-04',
            'reason_marriage_ended' => 'Other',
            'other_reason_marriage_ended' => 'Some other reason'
          },
          'first' => 'John',
          'middle' => 'oliver',
          'last' => 'Hamm',
          'suffix' => 'Sr.',
          'ssn' => '370947142',
          'birth_date' => '2009-03-03'
        }
      ],
      'deaths' => [
        {
          'deceased_date_of_death' => '2011-02-03',
          'deceased_location_of_death' => {
            'state' => 'California',
            'city' => 'Aomplea'
          },
          'full_name' => {
            'first' => 'John',
            'middle' => 'Henry',
            'last' => 'Doe',
            'suffix' => 'Sr.'
          },
          'dependent_type' => 'CHILD',
          'child_status' => {
            'child_under18' => true
          }
        },
        {
          'deceased_date_of_death' => '2012-03-03',
          'deceased_location_of_death' => {
            'state' => 'California',
            'city' => 'Clawson'
          },
          'full_name' => {
            'first' => 'Sally',
            'middle' => 'Bertram',
            'last' => 'Struthers',
            'suffix' => 'Jr.'
          },
          'dependent_type' => 'SPOUSE'
        },
        {
          'deceased_date_of_death' => '2009-03-04',
          'deceased_location_of_death' => {
            'state' => 'Michigan',
            'city' => 'Ann Arbor'
          },
          'full_name' => {
            'first' => 'Rob',
            'middle' => 'Bertram',
            'last' => 'Stark',
            'suffix' => 'II'
          },
          'dependent_type' => 'DEPENDENT_PARENT'
        }
      ],
      'spouse_information' => {
        'spouse_full_name' => {
          'first' => 'Jenny',
          'middle' => 'Lauren',
          'last' => 'McCarthy',
          'suffix' => 'Sr.'
        },
        'spouse_ssn' => '323454323',
        'spouse_dob' => '1981-04-04',
        'is_spouse_veteran' => true,
        'spouse_va_file_number' => '00000000',
        'spouse_service_number' => '11111111'
      },
      'current_spouse_address' => {
        'country_name' => 'United States',
        'address_line1' => '2037 29th St',
        'city' => 'Rock Island',
        'state_code' => 'IL',
        'zip_code' => '61201'
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
      },
      'report_divorce' => {
        'former_spouse_name' => {
          'first' => 'Ron',
          'middle' => 'Walter',
          'last' => 'Swanson'
        },
        'date_of_divorce' => '2001-02-03',
        'location_of_divorce' => {
          'state' => 'Michigan (MI)',
          'city' => 'Clawson'
        },
        'is_marriage_annulled_or_void' => true,
        'explanation_of_annullment_or_void' => 'Some stuff about the marriage being declared void.'
      }
    }
  end
  let(:person_address_phone_object) do
    ValueObjects::VnpPersonAddressPhone.new(
      vnp_proc_id: proc_id,
      vnp_participant_id: participant_id,
      first_name: 'Veteran first name',
      middle_name: 'Veteran middle name',
      last_name: 'Veteran last name',
      vnp_participant_address_id: '113372',
      participant_relationship_type_name: 'Spouse',
      family_relationship_type_name: 'Spouse',
      suffix_name: 'Jr',
      birth_date: '08/08/1988',
      birth_state_code: 'FL',
      birth_city_name: 'Tampa',
      file_number: '2345678',
      ssn_number: '112347',
      phone_number: '5555555555',
      address_line_one: '123 Mainstreet',
      address_line_two: '',
      address_line_three: '',
      address_state_code: 'FL',
      address_city: 'Tampa',
      address_zip_code: '22145',
      email_address: 'foo@foo.com',
      death_date: nil,
      begin_date: nil,
      end_date: nil,
      ever_married_indicator: 'N',
      marriage_state: '',
      marriage_city: 'Tampa',
      divorce_state: nil,
      divorce_city: nil,
      marriage_termination_type_cd: nil,
      benefit_claim_type_end_product: '681',
    )
  end

  describe '#create' do
    context 'adding children' do
      it 'returns an array of VnpPersonAddressPhone objects' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            veteran: person_address_phone_object,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    participant_relationship_type_name: "Child",
                                    address_line_one: "1019 Robin Cir",
                                    family_relationship_type_name: 'Biological'
                                  )
                                )
        end
      end
    end

    context 'reporting a death' do
      it 'returns an array of VnpPersonAddressPhone objects' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            veteran: person_address_phone_object,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    death_date: DateTime.new(2011,2,3,0,0,0, '-0600'),
                                  )
                                )
        end
      end
    end

    context 'adding a spouse' do
      it 'returns an array of VnpPersonAddressPhone objects' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            veteran: person_address_phone_object,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    marriage_state: 'California',
                                    marriage_city: 'Slawson'
                                  )
                                )
        end
      end
    end

    context 'reporting a divorce' do
      it 'returns an array of VnpPersonAddressPhone objects' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            veteran: person_address_phone_object,
            user: user
          ).create
          # ToDo this expectation will change when we get the new data keys from the FE
          expect(dependents).to include(
                                  an_object_having_attributes(
                                    divorce_state: "Michigan (MI)",
                                    divorce_city: "Clawson",
                                    marriage_termination_type_cd: "Some stuff about the marriage being declared void."
                                  )
                                )
        end
      end
    end

    context 'report marriage of a child under 18'
    context 'report step-child is no longer part of household'
    context 'report child has stopped attending school'
  end
end
