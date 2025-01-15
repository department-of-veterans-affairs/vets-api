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

  let(:address_result) do
    {
      'country_name' => 'USA',
      'address_line1' => '1100 Robin Cir',
      'city' => 'Los Angelas',
      'state_code' => 'CA',
      'zip_code' => '90210'
    }
  end

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
      formatted_info = described_class.new(child_info).format_info

      expect(formatted_info).to eq(format_info_output)
    end
  end

  describe '#address' do
    it 'formats address' do
      address = described_class.new(child_info).address(all_flows_payload['dependents_application'])

      expect(address).to eq(address_result)
    end
  end
end
