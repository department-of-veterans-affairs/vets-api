# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/direct_deposit/payment_account'

RSpec.describe Lighthouse::DirectDeposit::PaymentAccount do
  let(:account) do
    described_class.new(
      account_type: 'CHECKING',
      routing_number: '123456789',
      account_number: 'ABC456789'
    )
  end

  describe '#account_type' do
    context 'when in list' do
      it 'returns the capitalized account_type' do
        expect(account.account_type).to eq('Checking')
      end
    end

    context 'when not in list' do
      it 'is invalid' do
        account.account_type = 'invalid'
        expect(account).not_to be_valid
        expect(account.errors[:account_type]).to include('is not included in the list')
      end
    end
  end

  describe '#account_number' do
    it 'must be present' do
      account.account_number = nil
      expect(account).not_to be_valid
      expect(account.errors[:account_number]).to include(
        'is too short (minimum is 4 characters)',
        'is too long (maximum is 17 characters)'
      )
    end

    it 'accepts letters and digits' do
      expect(account).to be_valid
    end

    it 'does not allow non-alphanumeric characters' do
      account.account_number = '%as.12-'
      expect(account).not_to be_valid
    end

    context 'when length is between 4 and 17' do
      it 'is invalid' do
        (4..17).each do |length|
          account.account_number = ('1' * length)
          expect(account).to be_valid
        end
      end
    end

    context 'when length is less than 4' do
      it 'is invalid' do
        account.account_number = '123'
        expect(account).not_to be_valid
        expect(account.errors[:account_number]).to include('is too short (minimum is 4 characters)')
      end
    end

    context 'when length is more than 17' do
      it 'is invalid' do
        account.account_number = '1' * 18
        expect(account).not_to be_valid
        expect(account.errors[:account_number]).to include('is too long (maximum is 17 characters)')
      end
    end
  end
end
