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

  describe 'Subclasses' do
    let(:transaction1) { create(:address_transaction, transaction_id: 1) }
    let(:transaction2) { create(:email_transaction, transaction_id: 2) }
    let(:transaction3) { create(:telephone_transaction, transaction_id: 3) }

    it 'are queryable from the parent', :aggregate_failures do
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

  describe '.refresh_transaction_status()' do
    let(:user) { build(:user, :loa3) }
    let(:transaction1) { 
      create(:address_transaction,
        transaction_id: '0faf342f-5966-4d3f-8b10-5e9f911d07d2',
        user_uuid: user.uuid,
        transaction_status: 'RECEIVED'
      )
    }
    let(:service) { ::Vet360::ContactInformation::Service.new(user) }

    before do
      # vet360_id appears in the API request URI so we need it to match the cassette
      allow_any_instance_of(Mvi).to receive(:response_from_redis_or_service).and_return(
        MVI::Responses::FindProfileResponse.new(
          status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
          profile: build(:mvi_profile, vet360_id: '1')
        )
      )
    end

    it 'updates the transaction_status', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, transaction1.transaction_id)
        expect(updated_transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end

    end

    it 'updates the status', :aggregate_failures do
      VCR.use_cassette('vet360/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, transaction1.transaction_id)
        expect(updated_transaction.status).to eq(AsyncTransaction::Vet360::Base::COMPLETED)
      end

    end

    # it 'raises an exception if transaction not found in db', :aggregate_failures do
    # end

    # it 'raises an exception if transaction not found in vet360', :aggregate_failures do
    # end

    # it 'does not make an API request if the tx is finished', :aggregate_failures do
    # end


  end

end
