# frozen_string_literal: true

require 'rails_helper'

describe DisabilityCompensationsSerializer, type: :serializer do
  subject { serialize(compensation, serializer_class: described_class) }

  let(:compensation) { build(:disability_compensation) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it "includes :type" do
    expect(data['type']).to eq('direct_deposit/disability_compensations')
  end

  it 'includes :control_information' do
    expect(attributes['control_information']).to eq compensation[:control_information].deep_stringify_keys
  end

  it 'includes :payment_account' do
    expect(attributes['payment_account']).to eq compensation[:payment_account].deep_stringify_keys
  end

  it 'masks account number' do
    masked_account_number = StringHelpers.mask_sensitive(compensation[:payment_account][:account_number])
    expect(attributes['payment_account']['account_number']).to eq masked_account_number
  end

  it 'masks routing number' do
    masked_routing_number = StringHelpers.mask_sensitive(compensation[:payment_account][:routing_number])
    expect(attributes['payment_account']['routing_number']).to eq masked_routing_number
  end
end
