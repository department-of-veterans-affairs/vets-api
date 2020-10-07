# frozen_string_literal: true

require 'rails_helper'
require 'evss/ppiu/payment_information'

describe EVSS::PPIU::PaymentInformation do
  let(:payment_information) do
    described_class.new(
      payment_account: build(:ppiu_payment_account),
      payment_address: EVSS::PPIU::PaymentAddress.new(
        city: 'city'
      )
    )
  end

  context 'with an unauthorized user' do
    before do
      allow(payment_information).to receive(:authorized?).and_return(false)
    end

    it 'hides payment address and payment account' do
      expect(payment_information.payment_account.attributes).to eq(EVSS::PPIU::PaymentAccount.new.attributes)
      expect(payment_information.payment_address.attributes).to eq(EVSS::PPIU::PaymentAddress.new.attributes)
    end
  end

  context 'with an authorized user' do
    before do
      allow(payment_information).to receive(:authorized?).and_return(true)
    end

    it 'displays payment address and payment account' do
      expect(payment_information.payment_account.attributes).not_to eq(EVSS::PPIU::PaymentAccount.new.attributes)
      expect(payment_information.payment_address.attributes).not_to eq(EVSS::PPIU::PaymentAddress.new.attributes)
    end
  end
end
