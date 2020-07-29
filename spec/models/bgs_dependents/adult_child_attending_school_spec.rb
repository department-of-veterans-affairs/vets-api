# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::AdultChildAttendingSchool do
  let(:fixtures_path) { Rails.root.join('spec', 'fixtures', '686c', 'dependents') }
  let(:all_flows_payload) do
    payload = File.read("#{fixtures_path}/all_flows_payload.json")
    JSON.parse(payload)
  end
  let(:adult_child_attending_school) do
    described_class.new(all_flows_payload['dependents_application'])
  end
  let(:formatted_info_response) do
    {
      'ssn' => '370947141',
      'birth_date' => '2001-03-03',
      'ever_married_ind' => 'Y',
      'first' => 'Ernie',
      'middle' => 'bubkis',
      'last' => 'McCracken',
      'suffix' => 'II'
    }
  end
  let(:address_response) do
    {
      'country_name' => 'USA',
      'address_line1' => '1019 Robin Cir',
      'city' => 'Arroyo Grande',
      'state_code' => 'CA',
      'zip_code' => '93420'
    }
  end

  describe '#format_info' do
    it 'formats info' do
      formatted_info = adult_child_attending_school.format_info

      expect(formatted_info).to eq(formatted_info_response)
    end
  end

  describe '#address' do
    it 'formats info' do
      address = adult_child_attending_school.address

      expect(address).to eq(address_response)
    end
  end
end
