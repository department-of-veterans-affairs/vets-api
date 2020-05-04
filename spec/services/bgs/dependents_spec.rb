# frozen_string_literal: true

require 'rails_helper'
require 'bgs/value_objects/vnp_person_address_phone'

RSpec.describe BGS::Dependents do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:payload) do
    root = Rails.root.to_s
    f = File.read("#{root}/spec/services/bgs/support/final_payload.rb")
    JSON.parse(f)
  end

  describe '#create' do
    context 'adding children' do
      it 'returns an object for biological child that does not live with veteran' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    first_name: 'John',
                                    middle_name: 'oliver',
                                    last_name: 'Hamm',
                                    birth_city_name: 'Slawson',
                                    birth_state_code: 'CA',
                                    birth_date: DateTime.new(2009, 3, 3, 0, 0, 0, '-0600'),
                                    ssn_number: '370947142',
                                    participant_relationship_type_name: "Child",
                                    address_line_one: "1100 Robin Cir",
                                    address_city: 'Los Angelas',
                                    address_state_code: 'CA',
                                    address_zip_code: '90210',
                                    family_relationship_type_name: 'Biological'
                                  )
                                )
        end
      end

      it 'returns an object for adopted child that does live with veteran' do
        veteran_address_info = payload['dependents_application']['veteran_contact_information']['veteran_address']
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    first_name: 'Adopted first name',
                                    middle_name: 'adopted middle name',
                                    last_name: 'adopted last name',
                                    birth_city_name: 'Slawson',
                                    birth_state_code: 'CA',
                                    birth_date: DateTime.new(2010, 3, 3, 0, 0, 0, '-0600'),
                                    ssn_number: '370947143',
                                    participant_relationship_type_name: "Child",
                                    address_country: veteran_address_info['country_name'],
                                    address_line_one: veteran_address_info['address_line1'],
                                    address_state_code: veteran_address_info['state_code'],
                                    address_city: veteran_address_info['city'],
                                    address_zip_code: veteran_address_info['zip_code'],
                                    family_relationship_type_name: 'Adopted Child'
                                  )
                                )
        end
      end
    end

    context 'reporting a death' do
      it 'returns an object with a death date' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    death_date: DateTime.new(2011, 2, 3, 0, 0, 0, '-0600'),
                                  )
                                )
        end
      end
    end

    context 'adding a spouse' do
      it 'returns object for spouse who lives with veteran' do
        payload['spouse_does_live_with_veteran'] = true

        VCR.use_cassette('bgs/dependents/create/spouse/lives_with_veteran') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    first_name: 'Jenny',
                                    middle_name: 'Lauren',
                                    last_name: 'McCarthy',
                                    suffix_name: 'Sr.',
                                    marriage_state: 'CA',
                                    marriage_city: 'Slawson',
                                    birth_date: DateTime.new(1981, 4, 4, 0, 0, 0, '-0600'),
                                    ssn_number: '323454323',
                                    participant_relationship_type_name: 'Spouse',
                                    family_relationship_type_name: 'Spouse',
                                    address_country: payload['dependents_application']['veteran_contact_information']['veteran_address']['country_name'],
                                    address_line_one: payload['dependents_application']['veteran_contact_information']['veteran_address']['address_line1'],
                                    address_state_code: payload['dependents_application']['veteran_contact_information']['veteran_address']['state_code'],
                                    address_city: payload['dependents_application']['veteran_contact_information']['veteran_address']['city'],
                                    address_zip_code: payload['dependents_application']['veteran_contact_information']['veteran_address']['zip_code']
                                  )
                                )
        end
      end

      it 'returns object for spouse who has different address (separated)' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    first_name: 'Jenny',
                                    middle_name: 'Lauren',
                                    last_name: 'McCarthy',
                                    suffix_name: 'Sr.',
                                    marriage_state: 'CA',
                                    marriage_city: 'Slawson',
                                    birth_date: DateTime.new(1981, 4, 4, 0, 0, 0, '-0600'),
                                    ssn_number: '323454323',
                                    address_country: 'USA',
                                    participant_relationship_type_name: 'Spouse',
                                    family_relationship_type_name: 'Estranged Spouse',
                                    address_state_code: 'IL',
                                    address_city: 'Rock Island',
                                    address_line_one: '2037 29th St',
                                    address_zip_code: '61201'
                                  )
                                )
        end
      end

      it 'marks spouse as veteran' do
        VCR.use_cassette('bgs/dependents/create/spouse/is_veteran') do
          payload['add_child'] = false
          payload['report_death'] = false
          payload['report_divorce'] = false
          payload['report_stepchild_not_in_household'] = false
          payload['report_marriage_of_child_under18'] = false
          payload['report_child18_or_older_is_not_attending_school'] = false
          spouse_vet_hash = {'first' => 'Jenny', 'middle' => 'Lauren', 'last' => 'McCarthy', 'suffix' => 'Sr.', 'ssn' => '323454323', 'birth_date' => '1981-04-04', 'ever_maried_ind' => 'Y', "vet_ind" => "Y", "va_file_number" => "00000000", "service_number" => "11111111"}

          expect_any_instance_of(BGS::Base).to receive(:create_person)
                                                 .with(proc_id, '146952', spouse_vet_hash)
                                                 .and_call_original

          BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create
        end
      end
    end

    xcontext 'reporting a divorce' do
      it 'returns an object with divorce data' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          # ToDo this expectation will change when we get the new data keys from the FE
          expect(dependents).to include(
                                  an_object_having_attributes(
                                    divorce_state: 'MI',
                                    divorce_city: 'Clawson',
                                    marriage_termination_type_code: "Divorce"
                                  )
                                )
        end
      end
    end

    context 'reporting stepchild no longer part of household' do
      it 'returns an object that represents a stepchild getting half of their expenses paid' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    address_line_one: '412 Crooks Road',
                                    address_state_code: 'AL',
                                    address_city: 'Clawson',
                                    participant_relationship_type_name: 'Child',
                                    family_relationship_type_name: 'Stepchild',
                                    living_expenses_paid_amount: 'Half'
                                  )
                                )
        end
      end
    end

    context 'report marriage of a child under 18' do
      it 'returns an object that represents a married child under 18' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    first_name: 'James',
                                    middle_name: 'Quandry',
                                    last_name: 'Beanstalk',
                                    participant_relationship_type_name: 'Child',
                                    family_relationship_type_name: 'Other',
                                    event_date: '1977-02-01'
                                  )
                                )
        end
      end
    end

    context 'report child 18 or older has stopped attending school' do
      it 'returns an object that represents a married child under 18' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
                                  an_object_having_attributes(
                                    first_name: 'Billy',
                                    middle_name: 'Yohan',
                                    last_name: 'Johnson',
                                    participant_relationship_type_name: 'Child',
                                    family_relationship_type_name: 'Other',
                                    event_date: '2019-03-03'
                                  )
                                )
        end
      end
    end
  end
end
