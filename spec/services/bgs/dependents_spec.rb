# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::Dependents do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:fixtures_path) { "#{Rails.root}/spec/fixtures/686c/dependents" }
  let(:all_flows_payload) do
    payload = File.read("#{fixtures_path}/all_flows_payload.json")
    JSON.parse(payload)
  end

  describe '#create' do
    context 'adding children' do
      it 'returns a hash for biological child that does not live with veteran' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Biological',
              participant_relationship_type_name: 'Child',
              type: 'child'
            )
          )
        end
      end

      it 'returns a hash for adopted child that does live with veteran' do
        veteran_address_info = all_flows_payload.dig('dependents_application', 'veteran_contact_information', 'veteran_address')
        json = File.read("#{fixtures_path}/children/adopted_child_lives_with_veteran.json")
        payload = JSON.parse(json)
        VCR.use_cassette('bgs/dependents/children/apdopted_child_lives_with_veteran') do
          expect_any_instance_of(BGS::Base).to receive(:create_address)
            .with(anything, anything, veteran_address_info).at_most(4).times
            .and_call_original

          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Adopted Child',
              participant_relationship_type_name: 'Child',
              type: 'child'
            )
          )
        end
      end
    end

    context 'reporting a death' do
      it 'returns a hash with a child type death' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Child',
              participant_relationship_type_name: 'Child',
              type: 'death'
            )
          )
        end
      end
    end

    context 'adding a spouse' do
      it 'returns hash for spouse who lives with veteran' do
        json = File.read("#{fixtures_path}/spouse/spouse_lives_with_veteran.json")
        payload = JSON.parse(json)

        VCR.use_cassette('bgs/dependents/create/spouse/lives_with_veteran') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Spouse',
              participant_relationship_type_name: 'Spouse',
              marriage_city: 'Slawson',
              marriage_state: 'CA',
              type: 'spouse',
              begin_date: '2014-03-04'
            )
          )
        end
      end

      it 'returns hash for spouse who has different address (separated)' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Estranged Spouse',
              participant_relationship_type_name: 'Spouse',
              marriage_city: 'Slawson',
              marriage_state: 'CA',
              type: 'spouse',
              begin_date: '2014-03-04'
            )
          )
        end
      end

      it 'marks spouse as veteran' do
        json = File.read("#{fixtures_path}/spouse/spouse_is_veteran.json")
        payload = JSON.parse(json)
        spouse_vet_hash = {
          'first' => 'Jenny',
          'middle' => 'Lauren',
          'last' => 'McCarthy',
          'suffix' => 'Sr.',
          'ssn' => '323454323',
          'birth_date' => '1981-04-04',
          'ever_married_ind' => 'Y',
          'vet_ind' => 'Y',
          'va_file_number' => '00000000',
          'martl_status_type_cd' => 'Married'
        }

        VCR.use_cassette('bgs/dependents/create/spouse/is_veteran') do
          expect_any_instance_of(BGS::Base).to receive(:create_person)
            .with('3828033', '148993', spouse_vet_hash)
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
      it 'returns an hash with divorce data' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: payload,
            user: user
          ).create

          # TODO: this expectation will change when we get the new data keys from the FE
          expect(dependents).to include(
            an_object_having_attributes(
              divorce_state: 'MI',
              divorce_city: 'Clawson',
              marriage_termination_type_code: 'Divorce'
            )
          )
        end
      end
    end

    context 'reporting stepchild no longer part of household' do
      it 'returns an hash that represents a stepchild getting half of their expenses paid' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Stepchild',
              participant_relationship_type_name: 'Child',
              living_expenses_paid_amount: '.5'
            )
          )
        end
      end
    end

    context 'report marriage of a child under 18' do
      it 'returns a hash that represents a married child under 18' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              event_date: '1977-02-01',
              family_relationship_type_name: 'Other',
              participant_relationship_type_name: 'Child',
              type: 'child_marriage'
            )
          )
        end
      end
    end

    context 'report child 18 or older has stopped attending school' do
      it 'returns an hash that represents a married child under 18' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              participant_relationship_type_name: 'Child',
              family_relationship_type_name: 'Other',
              event_date: '2019-03-03',
              type: 'not_attending_school'
            )
          )
        end
      end
    end

    context 'report 674' do
      it 'returns a hash that represents child over 18 attending school' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user
          ).create

          expect(dependents).to include(
            a_hash_including(
              type: '674',
              participant_relationship_type_name: 'Child',
              family_relationship_type_name: 'Other'
            )
          )
        end
      end
    end
  end
end
