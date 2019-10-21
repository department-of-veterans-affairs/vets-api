# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PPIU::PaymentAccount do
  describe '.build_payment_account' do
    context 'with valid payment account attrs' do
      let(:payment_account) { build(:ppiu_payment_account) }

      it 'builds a payment account' do
        account = EVSS::PPIU::PaymentAccount.new(payment_account.as_json)
        expect(account).to be_valid
      end
    end

    context 'with missing `financial_institution_name attr`' do
      let(:payment_account) { build(:ppiu_payment_account, financial_institution_name: nil) }

      it 'builds a payment account' do
        account = EVSS::PPIU::PaymentAccount.new(payment_account.as_json)
        expect(account).to be_valid
      end
    end

    context 'with a missing payment account attr' do
      let(:payment_account) { build(:ppiu_payment_account, account_number: nil) }

      it 'reports as invalid and has errors' do
        address = EVSS::PPIU::PaymentAccount.new(payment_account.as_json)
        expect(address).not_to be_valid
        expect(address.errors.messages).to eq(
          account_number: ["can't be blank"]
        )
      end
    end

    context 'with an invalid payment account attr' do
      let(:payment_account) { build(:ppiu_payment_account, account_number: 'not a number') }

      it 'reports as invalid and has errors' do
        address = EVSS::PPIU::PaymentAccount.new(payment_account.as_json)
        expect(address).not_to be_valid
        expect(address.errors.messages).to eq(
          account_number: ['is invalid']
        )
      end
    end

    context 'with an invalid account type attr' do
      let(:payment_account) { build(:ppiu_payment_account, account_type: 'Double Savings') }

      it 'reports as invalid and has errors' do
        address = EVSS::PPIU::PaymentAccount.new(payment_account.as_json)
        expect(address).not_to be_valid
        expect(address.errors.messages).to eq(
          account_type: ['is not included in the list']
        )
      end
    end
  end
end
