# frozen_string_literal: true

require 'rails_helper'

describe PaymentHistorySerializer, type: :serializer do
  subject { serialize(payment_history, serializer_class: described_class) }

  let(:payments) do
    [{
      pay_check_dt: '2017-12-29T00:00:00.000-06:00',
      pay_check_amount: '$3,261.10',
      pay_check_type: 'Compensation & Pension - Recurring',
      payment_method: 'Direct Deposit',
      bank_name: 'NAVY FEDERAL CREDIT UNION',
      account_number: '***4567'
    }]
  end

  let(:return_payments) do
    [{
      returned_check_issue_dt: '2012-12-15T00:00:00.000-06:00',
      returned_check_cancel_dt: '2013-01-01T00:00:00.000-06:00',
      returned_check_amount: '$50.00',
      returned_check_number: '12345678',
      returned_check_type: 'CH31 VR&E',
      return_reason: 'Other Reason'
    }]
  end

  let(:payment_history) { PaymentHistory.new(payments:, return_payments:) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq 'payment_history'
  end

  it 'includes :payments' do
    expect(attributes['payments'].size).to eq payment_history.payments.size
  end

  it 'includes :payments with attributes' do
    expect(attributes['payments'].first).to eq payment_history.payments.first.deep_stringify_keys
  end

  it 'includes :return_payments' do
    expect(attributes['return_payments'].size).to eq payment_history.return_payments.size
  end

  it 'includes :return_payments with attributes' do
    expect(attributes['return_payments'].first).to eq payment_history.return_payments.first.deep_stringify_keys
  end
end
