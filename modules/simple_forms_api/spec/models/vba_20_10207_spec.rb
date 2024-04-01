# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::VBA2010207' do
  describe 'zip_code_is_us_based' do
    describe 'veteran address is present and in US' do
      it 'returns true' do
        data = { 'veteran_mailing_address' => { 'country' => 'USA' } }

        form = SimpleFormsApi::VBA2010207.new(data)

        expect(form.zip_code_is_us_based).to eq(true)
      end
    end

    describe 'veteran address is present and not in US' do
      it 'returns false' do
        data = { 'veteran_mailing_address' => { 'country' => 'Canada' } }

        form = SimpleFormsApi::VBA2010207.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end

    describe 'non-veteran address is present and in US' do
      it 'returns true' do
        data = { 'non_veteran_mailing_address' => { 'country' => 'USA' } }

        form = SimpleFormsApi::VBA2010207.new(data)

        expect(form.zip_code_is_us_based).to eq(true)
      end
    end

    describe 'non-veteran address is present and not in US' do
      it 'returns false' do
        data = { 'non_veteran_mailing_address' => { 'country' => 'Canada' } }

        form = SimpleFormsApi::VBA2010207.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end
  end

  describe 'currently_homeless?' do
    it 'returns true when the preparer is homeless' do
      data = { 'living_situation' => { 'SHELTER' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.currently_homeless?).to eq(true)
    end

    it 'returns false when the preparer is not homeless' do
      data = { 'living_situation' => {} }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.currently_homeless?).to eq(false)
    end
  end

  describe 'homeless_living_situation' do
    it 'returns 0 when the preparer is in a shelter' do
      data = { 'living_situation' => { 'SHELTER' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.homeless_living_situation).to eq(0)
    end

    it 'returns 1 when the preparer is with a friend or family' do
      data = { 'living_situation' => { 'FRIEND_OR_FAMILY' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.homeless_living_situation).to eq(1)
    end

    it 'returns 2 when the preparer is in an overnight place' do
      data = { 'living_situation' => { 'OVERNIGHT' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.homeless_living_situation).to eq(2)
    end

    it 'returns nil when the preparer is not homeless' do
      data = { 'living_situation' => {} }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.homeless_living_situation).to eq(nil)
    end
  end

  describe 'at_risk_of_being_homeless?' do
    it 'returns true when the preparer is at risk of being homeless' do
      data = { 'living_situation' => { 'LOSING_HOME' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.at_risk_of_being_homeless?).to eq(true)
    end

    it 'returns false when the preparer is not at risk of being homeless' do
      data = { 'living_situation' => {} }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.at_risk_of_being_homeless?).to eq(false)
    end
  end

  describe 'risk_homeless_living_situation' do
    it 'returns 0 when the preparer is losing their home' do
      data = { 'living_situation' => { 'LOSING_HOME' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.risk_homeless_living_situation).to eq(0)
    end

    it 'returns 1 when the preparer is leaving a shelter' do
      data = { 'living_situation' => { 'LEAVING_SHELTER' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.risk_homeless_living_situation).to eq(1)
    end

    it 'returns 2 when the preparer is experiencing another risk' do
      data = { 'living_situation' => { 'OTHER_RISK' => true } }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.risk_homeless_living_situation).to eq(2)
    end

    it 'returns nil when the preparer is not at risk of being homeless' do
      data = { 'living_situation' => {} }

      form = SimpleFormsApi::VBA2010207.new(data)

      expect(form.risk_homeless_living_situation).to eq(nil)
    end
  end

  describe 'requester_signature' do
    statement_of_truth_signature = 'John Veteran'
    [
      { preparer_type: 'veteran', third_party_type: nil, expected: statement_of_truth_signature },
      { preparer_type: 'non-veteran', third_party_type: nil, expected: nil },
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
      { preparer_type: 'non-veteran', third_party_type: nil, expected: statement_of_truth_signature },
      { preparer_type: 'third-party-non-veteran', third_party_type: 'representative',
        expected: statement_of_truth_signature },
      { preparer_type: 'third-party-veteran', third_party_type: 'representative',
        expected: statement_of_truth_signature },
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
