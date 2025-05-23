# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::MarriageHistory do
  let(:marriage_history_info) do
    {
      'start_date' => '2007-04-03',
      'start_location' => { 'state' => 'AK', 'city' => 'Rock Island' },
      'reason_marriage_ended' => 'Other',
      'reason_marriage_ended_other' => 'Some other reason',
      'end_date' => '2009-05-05',
      'end_location' => { 'state' => 'IL', 'city' => 'Chicago' },
      'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' }
    }
  end
  let(:marriage_history_info_v2) do
    {
      'start_date' => '2007-04-03',
      'start_location' => { 'location' => { 'state' => 'AK', 'city' => 'Rock Island' } },
      'reason_marriage_ended' => 'Other',
      'other_reason_marriage_ended' => 'Some other reason',
      'end_date' => '2009-05-05',
      'end_location' => { 'location' => { 'state' => 'IL', 'city' => 'Chicago' } },
      'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' }
    }
  end
  let(:formatted_params_result) do
    {
      'start_date' => '2007-04-03',
      'end_date' => '2009-05-05',
      'marriage_country' => nil,
      'marriage_state' => 'AK',
      'marriage_city' => 'Rock Island',
      'divorce_state' => 'IL',
      'divorce_city' => 'Chicago',
      'divorce_country' => nil,
      'marriage_termination_type_code' => 'Other',
      'first' => 'Billy',
      'middle' => 'Yohan',
      'last' => 'Johnson',
      'suffix' => 'Sr.'
    }
  end

  context 'with va_dependents_v2 turned off' do

    describe '#format_info' do
      it 'formats marriage history params for submission' do
        formatted_info = described_class.new(marriage_history_info, false).format_info

        expect(formatted_info).to eq(formatted_params_result)
      end
    end
  end

  context 'with va_dependents_v2 turned on' do

    describe '#format_info' do
      it 'formats marriage history params for submission' do
        formatted_info = described_class.new(marriage_history_info_v2, true).format_info

        expect(formatted_info).to eq(formatted_params_result)
      end
    end
  end
end
