# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::Vet360::Base, type: :model do

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

    it 'updates the transaction_status' do
        VCR.use_cassette('vet360/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, transaction1.transaction_id)
        expect(updated_transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end

    end

    it 'updates the status' do
      VCR.use_cassette('vet360/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, transaction1.transaction_id)
        expect(updated_transaction.status).to eq(AsyncTransaction::Vet360::Base::COMPLETED)
      end
    end

    it 'raises an exception if transaction not found in db' do
      $nonexistent_transaction_id = 9999999
      expect {
        AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, $nonexistent_transaction_id) 
      }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it 'does not make an API request if the tx is finished' do
      transaction1.status = AsyncTransaction::Vet360::Base::COMPLETED
      VCR.use_cassette('vet360/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, transaction1.transaction_id)
        expect(AsyncTransaction::Vet360::Base).to receive(:fetch_transaction).at_most(0)
      end

    end

  end

end
