# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::Vet360::Base, type: :model do
  before do
    allow(Flipper).to receive(:enabled?).with(:va_v3_contact_information_service, instance_of(User)).and_return(true)
  end

  describe '.refresh_transaction_status()', :skip_vet360 do
    let(:user) { build(:user, :loa3) }
    let(:transaction1) do
      create(:address_transaction,
             transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4',
             user_uuid: user.uuid,
             transaction_status: 'RECEIVED')
    end
    let(:transaction2) do
      create(:email_transaction,
             transaction_id: '5b4550b3-2bcb-4fef-8906-35d0b4b310a8',
             user_uuid: user.uuid,
             transaction_status: 'RECEIVED')
    end
    let(:service) { VAProfile::V2::ContactInformation::Service.new(user) }

    before do
      # vet360_id appears in the API request URI so we need it to match the cassette
      allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
        create(:find_profile_response, profile: build(:mpi_profile))
      )
    end

    it 'updates the transaction_status' do
      VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
          user,
          service,
          transaction1.transaction_id
        )
        expect(updated_transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end
    end

    it 'updates the status' do
      VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
          user,
          service,
          transaction1.transaction_id
        )
        expect(updated_transaction.status).to eq(AsyncTransaction::Vet360::Base::COMPLETED)
      end
    end

    it 'persists the messages from va_profile' do
      VCR.use_cassette('va_profile/v2/contact_information/email_transaction_status') do
        updated_transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
          user,
          service,
          transaction2.transaction_id
        )
        expect(updated_transaction.persisted?).to be(true)
        parsed_metadata = JSON.parse(updated_transaction.metadata)
        expect(parsed_metadata.is_a?(Array)).to be(true)
        expect(updated_transaction.metadata.present?).to be(true)
      end
    end

    it 'raises an exception if transaction not found in db' do
      expect do
        AsyncTransaction::Vet360::Base.refresh_transaction_status(user, service, 9_999_999)
      end.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it 'does not make an API request if the tx is finished' do
      transaction1.status = AsyncTransaction::Vet360::Base::COMPLETED
      VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
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
    let(:user) { build(:user, :loa3) }
    let!(:user_verification) { create(:user_verification, idme_uuid: user.idme_uuid) }

    let(:address) { build(:va_profile_v3_address, source_system_user: user.icn) }

    it 'returns an instance with the user uuid', :aggregate_failures do
      VCR.use_cassette('va_profile/v2/contact_information/post_address_success', VCR::MATCH_EVERYTHING) do
        service = VAProfile::V2::ContactInformation::Service.new(user)
        address.address_line1 = '1493 Martin Luther King Rd'
        address.city = 'Fulton'
        address.state_code = 'MS'
        address.zip_code = '38843'
        address.effective_start_date = '2024-08-27T18:51:06.000Z'
        address.source_date = '2024-08-27T18:51:06.000Z'
        response = service.post_address(address)
        transaction = AsyncTransaction::Vet360::Base.start(user, response)
        expect(transaction.user_uuid).to eq(user.uuid)
        expect(transaction.user_account).to eq(user.user_account)
        expect(transaction.class).to eq(AsyncTransaction::Vet360::Base)
      end
    end
  end

  describe '.fetch_transaction' do
    it 'raises an error if passed unrecognized transaction' do
      # Instead of simply calling Struct.new('Surprise'), we need to check that it hasn't been defined already
      # in order to prevent the following warning:
      # warning: redefining constant Struct::Surprise
      surprise_struct = Struct.const_defined?('Surprise') ? Struct::Surprise : Struct.new('Surprise')

      expect do
        AsyncTransaction::Vet360::Base.fetch_transaction(surprise_struct, nil)
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
    let(:service) { VAProfile::V2::ContactInformation::Service.new(user) }

    before do
      # vet360_id appears in the API request URI so we need it to match the cassette
      allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
        create(:find_profile_response, profile: build(:mpi_profile))
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
                           transaction_id: '5b4550b3-2bcb-4fef-8906-35d0b4b310a8',
                           user_uuid: user.uuid,
                           transaction_status: 'RECEIVED',
                           status: AsyncTransaction::Vet360::Base::REQUESTED)
      VCR.use_cassette('va_profile/v2/contact_information/email_transaction_status', VCR::MATCH_EVERYTHING) do
        transactions = AsyncTransaction::Vet360::Base.refresh_transaction_statuses(user, service)
        expect(transactions.size).to eq(1)
        expect(transactions.first.transaction_id).to eq(transaction.transaction_id)
      end
    end
  end
end
