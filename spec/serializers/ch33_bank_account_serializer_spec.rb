# frozen_string_literal: true

require 'rails_helper'

describe Ch33BankAccountSerializer, type: :serializer do
  subject { serialize(ch33_bank_account, serializer_class: described_class) }

  let(:ch33_bank_account) do
    {
      dposit_acnt_nbr: '123',
      dposit_acnt_type_nm: 'C',
      routng_trnsit_nbr: '122400724',
      financial_institution_name: 'BANK OF AMERICA, N.A.'
    }
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  context 'when :dposit_acnt_type_nm is C' do
    it 'includes :account_type is Checking' do
      expect(attributes['account_type']).to eq 'Checking'
    end
  end

  context 'when :dposit_acnt_type_nm is S' do
    let(:ch33_savings_account) { ch33_bank_account.merge(dposit_acnt_type_nm: 'S') }
    let(:savings_response) { serialize(ch33_savings_account, serializer_class: described_class) }
    let(:account_type) { JSON.parse(savings_response)['data']['attributes']['account_type'] }

    it 'includes :account_type is Savings' do
      expect(account_type).to eq 'Savings'
    end
  end

  it 'includes :account_number as sensitive' do
    masked_account_number = StringHelpers.mask_sensitive(ch33_bank_account[:dposit_acnt_nbr])
    expect(attributes['account_number']).to eq masked_account_number
  end

  it 'includes :financial_institution_routing_number as sensitive' do
    masked_routing_number = StringHelpers.mask_sensitive(ch33_bank_account[:routng_trnsit_nbr])
    expect(attributes['financial_institution_routing_number']).to eq masked_routing_number
  end

  it 'includes :financial_institution_name as sensitive' do
    expect(attributes['financial_institution_name']).to eq ch33_bank_account[:financial_institution_name]
  end
end
