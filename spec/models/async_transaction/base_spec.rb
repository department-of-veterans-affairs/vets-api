# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::Vet360::Base, type: :model do

  describe '.save' do

      it 'works' do
        saved = AsyncTransaction::Vet360::AddressTransaction.new(
            user_uuid: 'abcdef',
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
      let(:tx1) { build(:address_transaction) }
      it 'are queryable from the parent' do
        tx1.save
        r1 = AsyncTransaction::Vet360::Base.where(transaction_id: tx1.transaction_id, source: tx1.source).first
        expect(r1.id).to eq(tx1.id)
      end

  end


end
