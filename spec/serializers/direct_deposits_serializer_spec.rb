# frozen_string_literal: true

require 'rails_helper'

describe DirectDepositsSerializer, feature: :direct_deposit,
                                   team_owner: :vfs_authenticated_experience_backend, type: :serializer do
  subject { serialize(direct_deposit, serializer_class: described_class) }

  let(:direct_deposit) { build(:direct_deposit, :with_payment_account) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq('direct_deposits')
  end

  it 'includes :control_information' do
    expect(attributes['control_information']).to eq direct_deposit[:control_information].deep_stringify_keys
  end

  it 'includes :payment_account' do
    expect(attributes['payment_account']).to eq direct_deposit[:payment_account].deep_stringify_keys
  end

  it 'includes :veteran_status' do
    expect(attributes['veteran_status']).to eq direct_deposit[:veteran_status]
  end

  it 'masks account number' do
    masked_account_number = StringHelpers.mask_sensitive(direct_deposit[:payment_account][:account_number])
    expect(attributes['payment_account']['account_number']).to eq masked_account_number
  end

  it 'masks routing number' do
    masked_routing_number = StringHelpers.mask_sensitive(direct_deposit[:payment_account][:routing_number])
    expect(attributes['payment_account']['routing_number']).to eq masked_routing_number
  end

  context 'when payment_account does not exist' do
    let(:direct_deposit) { build(:direct_deposit) }

    it 'includes :payment_account as nil' do
      expect(attributes['payment_account']).to be_nil
    end
  end
end
