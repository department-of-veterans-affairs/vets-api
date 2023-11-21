# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/direct_deposit/payment_account'

RSpec.describe Lighthouse::DirectDeposit::PaymentAccount do
  describe '#account_type' do
    context 'when account_type is valid' do
      it 'returns the capitalized account_type' do
        account = described_class.new(account_type: 'CHECKING')
        expect(account.account_type).to eq('Checking')
      end
    end

    context 'when account_type is not valid' do
      it 'returns an error' do
        account = described_class.new(account_type: 'invalid')
        account.valid?
        expect(account.errors[:account_type]).to include('is not included in the list')
      end
    end
  end
end
