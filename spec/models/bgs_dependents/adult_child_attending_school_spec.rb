# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::AdultChildAttendingSchool do
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:adult_child_attending_school) do
    described_class.new(all_flows_payload['dependents_application'], false)
  end
  let(:adult_child_attending_school_v2) do
    described_class.new(all_flows_payload_v2['dependents_application']['student_information'][0], true)
  end
  let(:formatted_info_response) do
    {
      'ssn' => '370947141',
      'birth_date' => '2001-03-03',
      'ever_married_ind' => 'Y',
      'first' => 'Ernie',
      'middle' => 'bubkis',
      'last' => 'McCracken',
      'suffix' => 'II',
      'dependent_income' => 'Y'
    }
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
      'dependent_income' => 'Y'
    }
  end
  let(:address_response) do
    {
      'country_name' => 'USA',
      'address_line1' => '20374 Alexander Hamilton St',
      'address_line2' => 'apt 4',
      'address_line3' => 'Bldg 44',
      'city' => 'Arroyo Grande',
      'state_code' => 'CA',
      'zip_code' => '93420'
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

  context 'with va_dependents_v2 off' do

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

  context 'with va_dependents_v2 on' do

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
end
