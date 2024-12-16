# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA2010207 do
  it_behaves_like 'zip_code_is_us_based', %w[veteran_mailing_address non_veteran_mailing_address]

  describe 'requester_signature' do
    statement_of_truth_signature = 'John Veteran'
    [
      { preparer_type: 'veteran', third_party_type: nil, expected: statement_of_truth_signature },
      { preparer_type: 'non-veteran', third_party_type: nil, expected: statement_of_truth_signature },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'power-of-attorney', expected: nil }
    ].each do |data|
      preparer_type = data[:preparer_type]
      third_party_type = data[:third_party_type]
      expected = data[:expected]

      it 'returns the right string' do
        form = SimpleFormsApi::VBA2010207.new(
          {
            'preparer_type' => preparer_type,
            'third_party_type' => third_party_type,
            'statement_of_truth_signature' => statement_of_truth_signature
          }
        )

        expect(form.requester_signature).to eq(expected)
      end
    end
  end

  describe 'third_party_signature' do
    statement_of_truth_signature = 'John Veteran'
    [
      { preparer_type: 'veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'non-veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'representative',
        expected: statement_of_truth_signature },
      { preparer_type: 'third-party-veteran', third_party_type: 'representative',
        expected: statement_of_truth_signature },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'power-of-attorney',
        expected: statement_of_truth_signature }
    ].each do |data|
      preparer_type = data[:preparer_type]
      third_party_type = data[:third_party_type]
      expected = data[:expected]

      it 'returns the right string' do
        form = SimpleFormsApi::VBA2010207.new(
          {
            'preparer_type' => preparer_type,
            'third_party_type' => third_party_type,
            'statement_of_truth_signature' => statement_of_truth_signature
          }
        )

        expect(form.third_party_signature).to eq(expected)
      end
    end
  end

  describe 'power_of_attorney_signature' do
    statement_of_truth_signature = 'John Veteran'
    [
      { preparer_type: 'veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'non-veteran', third_party_type: nil, expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-veteran', third_party_type: 'representative', expected: nil },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'power-of-attorney',
        expected: statement_of_truth_signature }
    ].each do |data|
      preparer_type = data[:preparer_type]
      third_party_type = data[:third_party_type]
      expected = data[:expected]

      it 'returns the right string' do
        form = SimpleFormsApi::VBA2010207.new(
          {
            'preparer_type' => preparer_type,
            'third_party_type' => third_party_type,
            'statement_of_truth_signature' => statement_of_truth_signature
          }
        )

        expect(form.power_of_attorney_signature).to eq(expected)
      end
    end
  end
end
