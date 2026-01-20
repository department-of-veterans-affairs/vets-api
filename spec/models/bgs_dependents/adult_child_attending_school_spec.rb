# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::AdultChildAttendingSchool do
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:adult_child_attending_school_v2) do
    described_class.new(all_flows_payload_v2['dependents_application']['student_information'][0])
  end
  let(:formatted_info_response_v2) do
    {
      'ssn' => '987654321',
      'birth_date' => '2005-01-01',
      'ever_married_ind' => 'Y',
      'first' => 'test',
      'middle' => 'middle',
      'last' => 'student',
      'suffix' => nil,
      'dependent_income' => 'Y',
      'relationship_to_student' => 'Biological'
    }
  end
  let(:address_response_v2) do
    {
      'country' => 'USA',
      'street' => '123 fake street',
      'street2' => 'line2',
      'street3' => 'line3',
      'city' => 'portland',
      'state' => 'ME',
      'postal_code' => '04102'
    }
  end

  describe '#format_info' do
    it 'formats info' do
      formatted_info = adult_child_attending_school_v2.format_info

      expect(formatted_info).to eq(formatted_info_response_v2)
    end
  end

  describe '#address' do
    it 'formats info' do
      address = adult_child_attending_school_v2.address

      expect(address).to eq(address_response_v2)
    end
  end
end
