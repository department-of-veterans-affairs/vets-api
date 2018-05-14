# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::Vet360::Base, type: :model do
  describe '.refresh_transaction_status()' do
    let(:user) { build(:user, :loa3) }
    let(:transaction1) do
      create(:address_transaction,
             transaction_id: '0faf342f-5966-4d3f-8b10-5e9f911d07d2',
             user_uuid: user.uuid,
             transaction_status: 'RECEIVED')
    end
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
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
          user,
          service,
          transaction1.transaction_id
        )
        expect(updated_transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end
    end

    it 'updates the status' do
      VCR.use_cassette('vet360/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
          user,
          service,
          transaction1.transaction_id
        )
        expect(updated_transaction.status).to eq(AsyncTransaction::Vet360::Base::COMPLETED)
      end
    end

    it 'raises an exception if transaction not found in db' do
      expect do
        AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, 9_999_999)
      end.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it 'does not make an API request if the tx is finished' do
      transaction1.status = AsyncTransaction::Vet360::Base::COMPLETED
      VCR.use_cassette('vet360/contact_information/address_transaction_status') do
        AsyncTransaction::Vet360::Base.refresh_transaction_status(
          user,
          service,
          transaction1.transaction_id
        )
        expect(AsyncTransaction::Vet360::Base).to receive(:fetch_transaction).at_most(0)
      end
    end
  end

  describe '.start' do
    before do
      allow(user).to receive(:vet360_id).and_return('1')
    end
    let(:user) { build(:user, :loa3) }
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }
    it 'returns an instance with the user uuid', :aggregate_failures do
      VCR.use_cassette('vet360/contact_information/post_address_success', VCR::MATCH_EVERYTHING) do
        service = Vet360::ContactInformation::Service.new(user)
        response = service.post_address(address)
        transaction = AsyncTransaction::Vet360::Base.start(user, response)
        expect(transaction.user_uuid).to eq(user.uuid)
        expect(transaction.class).to eq(AsyncTransaction::Vet360::Base)
      end
    end
  end

  describe '.fetch_transaction' do
    it 'raises an error if passed unrecognized transaction' do
      expect do
        AsyncTransaction::Vet360::Base.fetch_transaction(Struct.new('Surprise'), nil)
      end.to raise_exception(RuntimeError)
    end
  end

  describe '.refresh_transaction_statuses()' do
    let(:user) { build(:user, :loa3) }
    let(:transaction1) do
      create(:address_transaction,
             transaction_id: '0faf342f-5966-4d3f-8b10-5e9f911d07d2',
             user_uuid: user.uuid,
             status: AsyncTransaction::Vet360::Base::COMPLETED)
    end
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

    it 'does not return completed transactions (whose status has not changed)' do
      transactions = AsyncTransaction::Vet360::Base.refresh_transaction_statuses(user, service)
      expect(transactions).to eq([])
    end

    it 'returns only the most recent transaction address/telephone/email transaction' do
      create(:email_transaction,
             transaction_id: 'foo',
             user_uuid: user.uuid,
             transaction_status: 'RECEIVED',
             status: AsyncTransaction::Vet360::Base::REQUESTED,
             created_at: Time.zone.now - 1)
      transaction = create(:email_transaction,
             transaction_id: '786efe0e-fd20-4da2-9019-0c00540dba4d',
             user_uuid: user.uuid,
             transaction_status: 'RECEIVED',
             status: AsyncTransaction::Vet360::Base::REQUESTED)
      VCR.use_cassette('vet360/contact_information/email_transaction_status', VCR::MATCH_EVERYTHING) do
        transactions = AsyncTransaction::Vet360::Base.refresh_transaction_statuses(user, service)
        expect(transactions.size).to eq(1)
        expect(transactions.first.transaction_id).to eq(transaction.transaction_id)
      end
    end
  end
end
