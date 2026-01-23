# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::ChildStoppedAttendingSchool do
  let(:child_info) do
    {
      'date_child_left_school' => '2019-03-03',
      'ssn' => '213648794',
      'birth_date' => '2003-03-03',
      'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' },
      'dependent_income' => 'Y'
    }
  end
  let(:formatted_params_result) do
    {
      'event_date' => '2019-03-03',
      'first' => 'Billy',
      'middle' => 'Yohan',
      'last' => 'Johnson',
      'suffix' => 'Sr.',
      'ssn' => '213648794',
      'birth_date' => '2003-03-03',
      'dependent_income' => 'Y'
    }
  end

  describe '#format_info' do
    it 'formats child stopped attending school params for submission' do
      formatted_info = described_class.new(child_info).format_info

      expect(formatted_info).to eq(formatted_params_result)
    end
  end
end
