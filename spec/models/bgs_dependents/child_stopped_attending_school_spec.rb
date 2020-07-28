# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::ChildStoppedAttendingSchool do
  describe '#format_info' do
    let(:child_info) do
      {
        'date_child_left_school' => '2019-03-03',
        'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' }
      }
    end
    let(:formatted_params_result) do
      {
        'event_date' => '2019-03-03',
        'first' => 'Billy',
        'middle' => 'Yohan',
        'last' => 'Johnson',
        'suffix' => 'Sr.'
      }
    end

    it 'formats relationship params for submission' do
      formatted_info = described_class.new(child_info).format_info

      expect(formatted_info).to include(formatted_params_result)
    end
  end
end
