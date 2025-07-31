# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::V0::DigitalDisputeSubmission do
  let(:form_submission) { create(:debts_api_digital_dispute_submission) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_uuid) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user_account).optional(false) }
  end

  describe '#register_failure' do
    let(:message) { 'Test error message' }

    it 'saves error message and sets failed state' do
      form_submission.register_failure(message)
      expect(form_submission.error_message).to eq(message)
      expect(form_submission.failed?).to be(true)
    end
  end

  describe '#register_success' do
    it 'sets the submission as submitted' do
      form_submission.register_success
      expect(form_submission.submitted?).to be(true)
    end
  end

  describe '#parsed_metadata' do
    context 'with valid metadata' do
      before do
        metadata = {
          'disputes' => [
            { 'composite_debt_id' => 'ABC123' }
          ]
        }
        form_submission.update(metadata: metadata.to_json)
      end

      it 'returns parsed metadata' do
        expect(form_submission.parsed_metadata).to eq({
                                                        'disputes' => [
                                                          { 'composite_debt_id' => 'ABC123' }
                                                        ]
                                                      })
      end
    end

    context 'with blank metadata' do
      before do
        form_submission.update(metadata: nil)
      end

      it 'returns empty hash' do
        expect(form_submission.parsed_metadata).to eq({})
      end
    end
  end

  describe '#store_public_metadata' do
    before do
      metadata = {
        'disputes' => [
          { 'debt_type' => 'overpayment', 'dispute_reason' => 'incorrect_amount' },
          { 'debt_type' => 'copay', 'dispute_reason' => 'already_paid' }
        ]
      }
      form_submission.update(metadata: metadata.to_json)
    end

    it 'extracts debt types and dispute reasons' do
      form_submission.store_public_metadata

      expect(form_submission.public_metadata['debt_types']).to contain_exactly('overpayment', 'copay')
      expect(form_submission.public_metadata['dispute_reasons']).to contain_exactly('incorrect_amount', 'already_paid')
    end
  end

  describe '#store_debt_identifiers' do
    let(:disputes) do
      [
        { 'composite_debt_id' => 'ABC123' },
        { 'composite_debt_id' => 'DEF456' }
      ]
    end

    it 'stores composite debt IDs' do
      form_submission.store_debt_identifiers(disputes)
      expect(form_submission.debt_identifiers).to eq(%w[ABC123 DEF456])
    end
  end
end
