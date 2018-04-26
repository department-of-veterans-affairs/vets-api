# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::Base, type: :model do
  describe 'Validation' do
    let(:transaction1) { create(:address_transaction) }
    let(:transaction2) { build(:address_transaction) }
    let(:transaction3) { build(:address_transaction, source: nil) }
    let(:transaction4) { build(:address_transaction) }

    it 'ensures uniqueness across source and transaction_id' do
      transaction2.transaction_id = transaction1.transaction_id
      expect(transaction2.valid?).to be false
    end

    it 'ensures presence of required fields' do
      expect(transaction3.valid?).to be false
    end

    it 'accepts a FactoryBot-made transaction' do
      expect(transaction4.valid?).to be true
    end
  end

  describe 'Subclasses' do
    let(:transaction1) { create(:address_transaction, transaction_id: 1) }
    let(:transaction2) { create(:email_transaction, transaction_id: 2) }
    let(:transaction3) { create(:telephone_transaction, transaction_id: 3) }

    it 'are queryable from the parent' do
      record1 = AsyncTransaction::Vet360::Base
                .where(transaction_id: transaction1.transaction_id, source: transaction1.source).first
      expect(record1.id).to eq(transaction1.id)
      expect(record1).to be_instance_of(AsyncTransaction::Vet360::AddressTransaction)

      record2 = AsyncTransaction::Vet360::Base
                .where(transaction_id: transaction2.transaction_id, source: transaction2.source).first
      expect(record2.id).to eq(transaction2.id)
      expect(record2).to be_instance_of(AsyncTransaction::Vet360::EmailTransaction)

      record3 = AsyncTransaction::Vet360::Base
                .where(transaction_id: transaction3.transaction_id, source: transaction3.source).first
      expect(record3.id).to eq(transaction3.id)
      expect(record3).to be_instance_of(AsyncTransaction::Vet360::TelephoneTransaction)
    end
  end
end
