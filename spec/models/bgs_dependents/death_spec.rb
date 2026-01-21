# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Death do
  let(:death_info_v2) do
    {
      'deceased_dependent_income' => 'N',
      'dependent_death_location' => { 'location' => { 'city' => 'portland', 'state' => 'ME' } },
      'dependent_death_date' => '2024-08-01',
      'dependent_type' => 'DEPENDENT_PARENT',
      'full_name' => { 'first' => 'first', 'middle' => 'middle', 'last' => 'last' },
      'ssn' => '987654321',
      'birth_date' => '1960-01-01'
    }
  end

  let(:formatted_params_result_v2) do
    {
      'death_date' => '2024-08-01T12:00:00+00:00',
      'vet_ind' => 'N',
      'ssn' => '987654321',
      'birth_date' => '1960-01-01',
      'first' => 'first',
      'middle' => 'middle',
      'last' => 'last',
      'dependent_income' => 'N'
    }
  end

  describe '#format_info' do
    it 'formats death params for submission' do
      formatted_info = described_class.new(death_info_v2).format_info

      expect(formatted_info).to eq(formatted_params_result_v2)
    end
  end

  describe '#format_info for spouse' do
    it 'formats death params for submission' do
      formatted_info = described_class.new(death_info_v2.merge({ 'dependent_type' => 'SPOUSE' })).format_info

      expect(formatted_info).to eq(formatted_params_result_v2.merge({ 'marriage_termination_type_code' => 'Death' }))
    end
  end
end
