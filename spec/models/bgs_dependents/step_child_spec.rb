# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::StepChild do
  let(:stepchild_info_v2) do
    {
      'supporting_stepchild' => true,
      'living_expenses_paid' => 'Half',
      'ssn' => '213685794',
      'birth_date' => '2010-03-03',
      'who_does_the_stepchild_live_with' => { 'first' => 'Adam', 'middle' => 'Steven', 'last' => 'Huberws' },
      'address' => {
        'country' => 'USA',
        'street' => '412 Crooks Road',
        'city' => 'Clawson',
        'state' => 'AL',
        'postal_code' => '48017'
      },
      'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' }
    }
  end
  let(:formatted_params_result) do
    {
      'living_expenses_paid' => '.5',
      'lives_with_relatd_person_ind' => 'N',
      'first' => 'Billy',
      'middle' => 'Yohan',
      'last' => 'Johnson',
      'ssn' => '213685794',
      'birth_date' => '2010-03-03',
      'suffix' => 'Sr.'
    }
  end

  describe '#format_info' do
    it 'formats stepchild params for submission' do
      formatted_info = described_class.new(stepchild_info_v2).format_info

      expect(formatted_info).to eq(formatted_params_result)
    end
  end
end
