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
          raw_params['contact_information']['email'] = 'not_an_email'

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:contact_information]).to include('must include a valid email address')
        end

        it 'validates phone number presence' do
          raw_params['contact_information'].delete('phone_number')

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:contact_information]).to include(
            'is missing required information: phone_number'
          )
        end

        it 'validates address_line1 presence' do
          raw_params['contact_information'].delete('address_line1')

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:contact_information]).to include(
            'is missing required information: address_line1'
          )
        end

        it 'validates city presence' do
          raw_params['contact_information'].delete('city')

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:contact_information]).to include('is missing required information: city')
        end
      end

      context 'when validating debt information' do
        it 'validates debt presence' do
          raw_params['debt_information'][0]['debt'] = nil

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:debt_information]).to include('entry #1: debt cannot be blank')
        end

        it 'validates dispute_reason presence' do
          raw_params['debt_information'][1]['dispute_reason'] = nil

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:debt_information]).to include('entry #2: dispute_reason cannot be blank')
        end

        it 'validates support_statement presence' do
          raw_params['debt_information'][0]['support_statement'] = nil

          digital_dispute = described_class.new(ActionController::Parameters.new(raw_params).permit!, user)

          digital_dispute.valid?
          expect(digital_dispute).not_to be_valid
          expect(digital_dispute.errors[:debt_information]).to include('entry #1: support_statement cannot be blank')
        end
      end
    end
  end
end
