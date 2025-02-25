# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::V0::DigitalDispute do
  describe 'validations' do
    let(:user) { build(:user, :loa3) }
    let(:raw_params) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/digital_disputes/standard_submission')
    end

    let(:params) { ActionController::Parameters.new(raw_params) }

    it 'validates proper parameters' do
      digital_dispute = described_class.new(params.permit!.to_h, user)

      expect(digital_dispute).to be_valid
    end

    context 'when invalid' do
      context 'when validating contact information' do
        it 'validates email address' do
          raw_params['veteran_information']['email'] = 'not_an_email'

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:veteran_information]).to include('must include a valid email address')
        end

        it 'validates mobile_phone presence' do
          raw_params['veteran_information'].delete('mobile_phone')

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:veteran_information]).to include(
            'is missing required information: mobile_phone'
          )
        end

        it 'validates mailing_address presence' do
          raw_params['veteran_information'].delete('mailing_address')

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:veteran_information]).to include(
            'is missing required information: mailing_address'
          )
        end
      end

      context 'when validating debt information' do
        it 'validates debt presence' do
          raw_params['selected_debts'][0]['debt_type'] = nil

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:selected_debts]).to include('entry #1: debt_type cannot be blank')
        end

        it 'validates dispute_reason presence' do
          raw_params['selected_debts'][1]['dispute_reason'] = nil

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:selected_debts]).to include('entry #2: dispute_reason cannot be blank')
        end

        it 'validates support_statement presence' do
          raw_params['selected_debts'][0]['support_statement'] = nil

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:selected_debts]).to include('entry #1: support_statement cannot be blank')
        end
      end
    end
  end

  describe '#sanitized_json' do
    let(:user) { build(:user, :loa3) }
    let(:raw_params) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/digital_disputes/standard_submission')
    end

    let(:params) { ActionController::Parameters.new(raw_params) }

    it 'returns a sanitized json' do
      digital_dispute = described_class.new(params.permit!.to_h, user)

      expect(digital_dispute.sanitized_json).to eq(raw_params)
    end
  end
end
