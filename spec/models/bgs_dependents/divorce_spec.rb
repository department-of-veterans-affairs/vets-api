# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Divorce do
  let(:divorce_info_v2) do
    {
      'date' => '2020-01-01',
      'ssn' => '848525794',
      'birth_date' => '1990-03-03',
      'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' },
      'divorce_location' => { 'location' => { 'state' => 'FL', 'city' => 'Tampa' } },
      'reason_marriage_ended' => 'Divorce',
      'spouse_income' => 'N'
    }
  end
  let(:formatted_params_result) do
    {
      'divorce_state' => 'FL',
      'divorce_city' => 'Tampa',
      'ssn' => '848525794',
      'birth_date' => '1990-03-03',
      'divorce_country' => nil,
      'marriage_termination_type_code' => 'Divorce',
      'end_date' => DateTime.parse("#{divorce_info_v2['date']} 12:00:00").to_time.iso8601,
      'vet_ind' => 'N',
      'type' => 'divorce',
      'first' => 'Billy',
      'middle' => 'Yohan',
      'last' => 'Johnson',
      'suffix' => 'Sr.',
      'spouse_income' => 'N'
    }
  end

  describe '#format_info' do
    it 'formats divorce params for submission' do
      formatted_info = described_class.new(divorce_info_v2).format_info

      expect(formatted_info).to eq(formatted_params_result)
    end
  end
end
