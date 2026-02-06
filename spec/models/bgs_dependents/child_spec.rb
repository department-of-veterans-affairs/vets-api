# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Child do
  let(:child_info_v2) do
    {
      'does_child_live_with_you' => true,
      'income_in_last_year' => 'N',
      'birth_location' => { 'location' => { 'state' => 'NH', 'city' => 'Concord', 'postal_code' => '03301' } },
      'is_biological_child' => true,
      'has_child_ever_been_married' => true,
      'marriage_end_date' => '2024-06-01',
      'marriage_end_reason' => 'annulment',
      'marriage_end_description' => 'description of annulment',
      'full_name' => { 'first' => 'first', 'middle' => 'middle', 'last' => 'last' },
      'ssn' => '987654321',
      'birth_date' => '2005-01-01',
      'does_child_have_permanent_disability' => false
    }
  end
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }

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
  let(:multiple_children_v2) { build(:dependency_claim_v2) }

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
        'not_self_sufficient' => 'N'
      }
    end

    it 'formats relationship params for submission' do
      formatted_info = described_class.new(child_info_v2).format_info

      expect(formatted_info).to eq(format_info_output)
    end

    it 'handles multiple formats of child relationships' do
      children = multiple_children_v2.parsed_form['dependents_application']['children_to_add'].map do |child_info|
        described_class.new(child_info).format_info
      end
      expect(children).to match([a_hash_including('family_relationship_type' => 'Biological'),
                                 a_hash_including('family_relationship_type' => 'Stepchild'),
                                 a_hash_including('family_relationship_type' => 'Adopted Child'),
                                 a_hash_including('family_relationship_type' => 'Biological'),
                                 a_hash_including('family_relationship_type' => 'Adopted Child'),
                                 a_hash_including('family_relationship_type' => 'Biological')])
    end
  end

  describe '#address' do
    it 'formats address' do
      address = described_class.new(child_info_v2).address(all_flows_payload_v2['dependents_application'])

      expect(address).to eq(address_result_v2)
    end
  end
end
