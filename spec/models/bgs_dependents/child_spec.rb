# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Child do
  let(:child_info) do
    {
      'does_child_live_with_you' => false,
      'child_income' => false,
      'child_address_info' => {
        'person_child_lives_with' => { 'first' => 'Bill', 'middle' => 'Oliver', 'last' => 'Bradsky' },
        'address' => {
          'country_name' => 'USA',
          'address_line1' => '1100 Robin Cir',
          'city' => 'Los Angelas',
          'state_code' => 'CA',
          'zip_code' => '90210'
        }
      },
      'place_of_birth' => { 'state' => 'CA', 'city' => 'Slawson' },
      'child_status' => { 'biological' => true },
      'previously_married' => 'Yes',
      'previous_marriage_details' => { 'date_marriage_ended' => '2018-03-04', 'reason_marriage_ended' => 'Death' },
      'full_name' => { 'first' => 'John', 'middle' => 'oliver', 'last' => 'Hamm', 'suffix' => 'Sr.' },
      'ssn' => '370947142',
      'birth_date' => '2009-03-03',
      'not_self_sufficient' => false
    }
  end
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }

  let(:child_info_v2) do
    {
      'does_child_live_with_you' => true,
      'income_in_last_year' => false,
      'birth_location' => { 'location' => { 'state' => 'NH', 'city' => 'Concord', 'postal_code' => '03301' } },
      'relationship_to_child' => { 'biological' => true },
      'has_child_ever_been_married' => true,
      'marriage_end_date' => '2024-06-01',
      'marriage_end_reason' => 'annulment',
      'marriage_end_description' => 'description of annulment',
      'full_name' => { 'first' => 'first', 'middle' => 'middle', 'last' => 'last' },
      'ssn' => '987654321',
      'birth_date' => '2005-01-01'
    }
  end
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }

  let(:address_result) do
    {
      'country_name' => 'USA',
      'address_line1' => '1100 Robin Cir',
      'city' => 'Los Angelas',
      'state_code' => 'CA',
      'zip_code' => '90210'
    }
  end
  let(:address_result_v2) do
    {
      'country' => 'USA',
      'street' => '123 fake street',
      'street2' => 'test2',
      'street3' => 'test3',
      'city' => 'portland',
      'state' => 'ME',
      'postal_code' => '04102'
    }
  end

  context 'with va_dependents_v2 off' do
    describe '#format_info' do
      let(:format_info_output) do
        {
          'ssn' => '370947142',
          'family_relationship_type' => 'Biological',
          'place_of_birth_state' => 'CA',
          'place_of_birth_city' => 'Slawson',
          'reason_marriage_ended' => 'Death',
          'ever_married_ind' => 'Y',
          'birth_date' => '2009-03-03',
          'place_of_birth_country' => nil,
          'first' => 'John',
          'middle' => 'oliver',
          'last' => 'Hamm',
          'suffix' => 'Sr.',
          'child_income' => 'N',
          'not_self_sufficient' => 'N'
        }
      end

      it 'formats relationship params for submission' do
        formatted_info = described_class.new(child_info, is_v2: false).format_info

        expect(formatted_info).to eq(format_info_output)
      end
    end

    describe '#address' do
      it 'formats address' do
        address = described_class.new(child_info, is_v2: false).address(all_flows_payload['dependents_application'])

        expect(address).to eq(address_result)
      end
    end
  end

  context 'with va_dependents_v2 on' do
    describe '#format_info' do
      let(:format_info_output) do
        {
          'ssn' => '987654321',
          'family_relationship_type' => 'Biological',
          'place_of_birth_state' => 'NH',
          'place_of_birth_city' => 'Concord',
          'reason_marriage_ended' => 'annulment',
          'ever_married_ind' => 'Y',
          'birth_date' => '2005-01-01',
          'place_of_birth_country' => nil,
          'first' => 'first',
          'middle' => 'middle',
          'last' => 'last',
          'suffix' => nil,
          'child_income' => 'N',
          'not_self_sufficient' => nil
        }
      end

      it 'formats relationship params for submission' do
        formatted_info = described_class.new(child_info_v2, is_v2: true).format_info

        expect(formatted_info).to eq(format_info_output)
      end
    end

    describe '#address' do
      it 'formats address' do
        address = described_class.new(child_info_v2,
                                      is_v2: true).address(all_flows_payload_v2['dependents_application'])

        expect(address).to eq(address_result_v2)
      end
    end
  end
end
