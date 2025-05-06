# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/utils'

RSpec.describe FsrFormTransform::Utils do
  include FsrFormTransform::Utils

  describe 'sanitize_date_string' do
    context 'when the input is empty' do
      it 'returns an empty string' do
        expect(sanitize_date_string('')).to eq('')
      end
    end

    context 'when the input contains XX in the month' do
      it "replaces 'XX' with '01' and formats correctly" do
        expect(sanitize_date_string('2024-XX')).to eq('01/2024')
      end
    end

    context 'when the input is a partial date (year and month)' do
      it 'formats the date correctly' do
        expect(sanitize_date_string('2024-12')).to eq('12/2024')
      end
    end

    context 'when the input contains a single-digit month' do
      it 'pads the month with a leading zero' do
        expect(sanitize_date_string('2024-1')).to eq('01/2024')
      end
    end

    context 'when the input is a full date (year, month, and day)' do
      it 'extracts and formats the month and year correctly' do
        expect(sanitize_date_string('2024-12-01')).to eq('12/2024')
      end
    end

    context 'when the input is an invalid format' do
      it 'raises an error' do
        expect { sanitize_date_string('invalid') }.to raise_error(NoMethodError)
      end
    end
  end
end
