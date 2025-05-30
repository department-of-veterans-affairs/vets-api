# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependentsV2::ChildMarriage do
  let(:child_marriage_info) do
    {
      'date_married' => '1977-02-01',
      'ssn' => '555612341',
      'birth_date' => '2020-01-01',
      'full_name' => { 'first' => 'Billy', 'middle' => 'Yohan', 'last' => 'Johnson', 'suffix' => 'Sr.' },
      'dependent_income' => true
    }
  end

  let(:formatted_params_result) do
    {
      'event_date' => '1977-02-01',
      'first' => 'Billy',
      'middle' => 'Yohan',
      'last' => 'Johnson',
      'suffix' => 'Sr.',
      'ssn' => '555612341',
      'birth_date' => '2020-01-01',
      'ever_married_ind' => 'Y',
      'dependent_income' => 'Y'
    }
  end

  context 'va_dependents_v2 is on' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
    end

    describe '#format_info' do
      it 'formats child marriage params for submission' do
        formatted_info = described_class.new(child_marriage_info).format_info

        expect(formatted_info).to eq(formatted_params_result)
      end
    end
  end
end
