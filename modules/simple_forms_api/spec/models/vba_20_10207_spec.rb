# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA2010207 do
  describe 'zip_code_is_us_based' do
    subject(:zip_code_is_us_based) { described_class.new(data).zip_code_is_us_based }

    context 'veteran address is present and in US' do
      let(:data) { { 'veteran_mailing_address' => { 'country' => 'USA' } } }

      it 'returns true' do
        expect(zip_code_is_us_based).to eq(true)
      end
    end

    context 'veteran address is present and not in US' do
      let(:data) { { 'veteran_mailing_address' => { 'country' => 'Canada' } } }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end

    context 'non-veteran address is present and in US' do
      let(:data) { { 'non_veteran_mailing_address' => { 'country' => 'USA' } } }

      it 'returns true' do
        expect(zip_code_is_us_based).to eq(true)
      end
    end

    context 'non-veteran address is present and not in US' do
      let(:data) { { 'non_veteran_mailing_address' => { 'country' => 'Canada' } } }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end

    context 'no valid address is given' do
      let(:data) { {} }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end
  end

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

  describe 'handle_attachments' do
    it 'saves the combined pdf' do
      combined_pdf = double
      original_file_path = 'original-file-path'
      attachment = double(to_pdf: double)
      allow(PersistentAttachment).to receive(:where).and_return([attachment])
      form = SimpleFormsApi::VBA2010207.new(
        {
          'financial_hardship_documents' => [{ confirmation_code: double }],
          'als_documents' => [{ confirmation_code: double }]
        }
      )
      allow(CombinePDF).to receive(:new).and_return(combined_pdf)
      allow(combined_pdf).to receive(:<<)
      allow(CombinePDF).to receive(:load)
      allow(CombinePDF).to receive(:load).with(original_file_path)
      allow(CombinePDF).to receive(:load).with(attachment).twice
      allow(combined_pdf).to receive(:save).with(original_file_path)

      form.handle_attachments(original_file_path)

      expect(combined_pdf).to have_received(:save).with(original_file_path)
    end
  end
end
