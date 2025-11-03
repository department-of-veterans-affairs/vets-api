# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::Base, type: :model do
  describe 'Validation' do
    let(:transaction1) { create(:address_transaction) }
    let(:transaction2) { build(:address_transaction) }
    let(:transaction3) { build(:address_transaction, source: nil) }
    let(:transaction4) { build(:address_transaction) }

    it 'ensures uniqueness across source and transaction_id', :aggregate_failures do
      transaction2.transaction_id = transaction1.transaction_id
      expect(transaction2.valid?).to be false
      expect(transaction2.errors[:transaction_id])
        .to eq(['Transaction ID must be unique within a source.'])
    end

    it 'ensures presence of required fields' do
      expect(transaction3.valid?).to be false
    end

    it 'accepts a FactoryBot-made transaction' do
      expect(transaction4.valid?).to be true
    end
  end

  describe 'Serialization' do
    let(:transaction) { build(:address_transaction) }

    it 'JSON encodes metadata' do
      transaction.update(metadata: { unserialized: 'data' })
      expect(transaction.metadata.is_a?(String)).to be true
    end
  end

  describe 'Subclasses' do
    let(:transaction1) { create(:address_transaction, transaction_id: 1) }
    let(:transaction2) { create(:email_transaction, transaction_id: 2) }
    let(:transaction3) { create(:telephone_transaction, transaction_id: 3) }

    it 'are queryable from the parent', :aggregate_failures do
      record1 = AsyncTransaction::VAProfile::Base
                .where(transaction_id: transaction1.transaction_id, source: transaction1.source).first
      expect(record1.id).to eq(transaction1.id)
      expect(record1).to be_instance_of(AsyncTransaction::VAProfile::AddressTransaction)

      record2 = AsyncTransaction::VAProfile::Base
                .where(transaction_id: transaction2.transaction_id, source: transaction2.source).first
      expect(record2.id).to eq(transaction2.id)
      expect(record2).to be_instance_of(AsyncTransaction::VAProfile::EmailTransaction)

      record3 = AsyncTransaction::VAProfile::Base
                .where(transaction_id: transaction3.transaction_id, source: transaction3.source).first
      expect(record3.id).to eq(transaction3.id)
      expect(record3).to be_instance_of(AsyncTransaction::VAProfile::TelephoneTransaction)
    end
  end

  describe '.stale scope' do
    it 'finds transactions that are eligible to be destroyed', :aggregate_failures do
      stale_age  = AsyncTransaction::Base::DELETE_COMPLETED_AFTER + 1.day
      active_age = AsyncTransaction::Base::DELETE_COMPLETED_AFTER - 1.day

      stale_transaction = create(
        :address_transaction,
        created_at: (Time.current - stale_age).iso8601,
        status: AsyncTransaction::Base::COMPLETED
      )
      create(
        :telephone_transaction,
        created_at: (Time.current - active_age).iso8601,
        status: AsyncTransaction::Base::COMPLETED
      )

      transactions = AsyncTransaction::Base.stale

      expect(transactions.count).to eq 1
      expect(transactions.first).to eq stale_transaction
    end
  end
end
