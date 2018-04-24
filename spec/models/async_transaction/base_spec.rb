# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::Base, type: :model do
  describe '.save' do
    it 'works' do
      saved = AsyncTransaction::Base.new(
        user_uuid: 'abcdef',
        type: 'AsyncTransaction::Vet360::AddressTransaction',
        source_id: 42,
        source: 'vet360',
        status: 'sent',
        transaction_id: 10
      ).save
      expect(saved).to be true
    end
  end

  describe 'Validation' do
    it 'ensures uniqueness across source and transaction_id' do
      AsyncTransaction::Vet360::AddressTransaction.new(
        user_uuid: 'abcdef',
        source_id: 42,
        source: 'vet360',
        status: 'sent',
        transaction_id: 10
      ).save
      tx2 = AsyncTransaction::Vet360::AddressTransaction.new(
        user_uuid: 'abcdef',
        source_id: 42,
        source: 'vet360',
        status: 'sent',
        transaction_id: 10
      )
      expect(tx2.valid?).to be false
    end

    it 'ensures presence of required fields' do
      tx1 = AsyncTransaction::Vet360::AddressTransaction.new(
        user_uuid: 'abcdef',
        source_id: 42,
        # source: 'vet360',
        status: 'sent',
        transaction_id: 10
      )
      expect(tx1.valid?).to be false
    end
  end

  describe 'Subclasses' do
    let(:tx1) { build(:address_transaction, transaction_id: 1) }
    let(:tx2) { build(:email_transaction, transaction_id: 2) }
    let(:tx3) { build(:telephone_transaction, transaction_id: 3) }

    it 'are queryable from the parent' do
      tx1.save
      r1 = AsyncTransaction::Vet360::Base.where(transaction_id: tx1.transaction_id, source: tx1.source).first
      expect(r1.id).to eq(tx1.id)
      expect(r1).to be_instance_of(AsyncTransaction::Vet360::AddressTransaction)

      tx2.save
      r2 = AsyncTransaction::Vet360::Base.where(transaction_id: tx2.transaction_id, source: tx2.source).first
      expect(r2.id).to eq(tx2.id)
      expect(r2).to be_instance_of(AsyncTransaction::Vet360::EmailTransaction)

      tx3.save
      r3 = AsyncTransaction::Vet360::Base.where(transaction_id: tx3.transaction_id, source: tx3.source).first
      expect(r3.id).to eq(tx3.id)
      expect(r3).to be_instance_of(AsyncTransaction::Vet360::TelephoneTransaction)
    end
  end
end
