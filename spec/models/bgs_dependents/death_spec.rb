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
  let(:death_info_v2) do
    {
      'deceased_dependent_income' => false,
      'dependent_death_location' => { 'location' => { 'city' => 'portland', 'state' => 'ME' } },
      'dependent_death_date' => '2024-08-01',
      'dependent_type' => 'DEPENDENT_PARENT',
      'full_name' => { 'first' => 'first', 'middle' => 'middle', 'last' => 'last' },
      'ssn' => '987654321',
      'birth_date' => '1960-01-01'
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

  context 'with va_dependents_v2 off' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
    end

    describe '#format_info' do
      it 'formats death params for submission' do
        formatted_info = described_class.new(death_info).format_info

        expect(formatted_info).to eq(formatted_params_result)
      end
    end
  end

  context 'with va_dependents_v2 on' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
    end

    describe '#format_info' do
      it 'formats death params for submission' do
        formatted_info = described_class.new(death_info_v2).format_info

        expect(formatted_info).to eq(formatted_params_result_v2)
      end
    end
  end
end
