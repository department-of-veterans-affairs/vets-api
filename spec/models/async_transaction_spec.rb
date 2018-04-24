# frozen_string_literal: true

require 'rails_helper'
# require 'models/async_transaction/base.rb'

RSpec.describe AsyncTransaction::Vet360::AddressTransaction, type: :model do
  # pending "add some examples to (or delete) #{__FILE__}"

  # subject { described_class.new(params) }


  describe 'Validation' do


      it 'ensures uniqueness across source_id and transaction_id' do
        tx1 = AsyncTransaction::Vet360::AddressTransaction.new(source_id: 10, transaction_id: 10).save

        tx2 = AsyncTransaction::Vet360::AddressTransaction.new(source_id: 10, transaction_id: 10);

        expect(tx2.valid?).to eq(false)
      end


  end


end
