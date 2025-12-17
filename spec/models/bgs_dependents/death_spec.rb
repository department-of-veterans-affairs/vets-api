# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Death do
  let(:death_info) do
    {
      'date' => '2019-03-03',
      'vet_ind' => 'N',
      'ssn' => '846685794',
      'birth_date' => '2009-03-03',
      'location' => { 'state' => 'CA', 'city' => 'Hollywood' },
      'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' },
      'dependent_type' => 'CHILD',
      'child_status' => { 'child_under18' => true },
      'dependent_income' => false
    }
  end
  let(:formatted_params_result) do
    {
      'death_date' => '2019-03-03T12:00:00+00:00',
      'vet_ind' => 'N',
      'ssn' => '846685794',
      'birth_date' => '2009-03-03',
      'first' => 'Billy',
      'middle' => 'Yohan',
      'last' => 'Johnson',
      'suffix' => 'Sr.',
      'dependent_income' => 'N'
    }
  end

  describe '#format_info' do
    it 'formats death params for submission' do
      formatted_info = described_class.new(death_info).format_info

      expect(formatted_info).to eq(formatted_params_result)
    end
  end

  describe '#format_info for spouse' do
    it 'formats death params for submission' do
      formatted_info = described_class.new(death_info.merge({ 'dependent_type' => 'SPOUSE' })).format_info

      expect(formatted_info).to eq(formatted_params_result.merge({ 'marriage_termination_type_code' => 'Death' }))
    end
  end
end
