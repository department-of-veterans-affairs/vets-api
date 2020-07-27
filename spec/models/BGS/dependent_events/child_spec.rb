# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependentEvents::Child do
  describe '#format_info' do
    let(:child_hash) do
      {
        'does_child_live_with_you' => false,
        'child_address_info' => {
          'person_child_lives_with' => {
            'first' => 'Bill', 'middle' => 'Oliver', 'last' => 'Bradsky'
          },
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
        'birth_date' => '2009-03-03'
      }
    end

    it 'returns a proper formatted hash' do
      child = described_class.new(child_hash)

      expect(child.format_info).to eq(
        {
          'ssn' => '370947142',
          'family_relationship_type' => 'Biological',
          'place_of_birth_state' => 'CA',
          'place_of_birth_city' => 'Slawson',
          'reason_marriage_ended' => 'Death',
          'ever_married_ind' => 'Y',
          'first' => 'John',
          'middle' => 'oliver',
          'last' => 'Hamm',
          'suffix' => 'Sr.'
        }
      )
    end
  end
end
