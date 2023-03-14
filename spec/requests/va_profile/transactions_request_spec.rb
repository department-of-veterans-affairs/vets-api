# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'transactions' do
  include SchemaMatchers
  let(:vet360_id) { '1' }
  let(:user) { build(:user, :loa3, vet360_id: vet360_id) }

  before do
    allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
    user.vet360_contact_info
    sign_in_as(user)
  end

  describe 'GET /v0/profile/status/:transaction_id' do
    context 'when the requested transaction exists' do
      context 'with a va profile transaction' do
        it 'responds with a serialized transaction', :aggregate_failures do
          transaction = create(
            :va_profile_address_transaction,
            user_uuid: user.uuid,
            transaction_id: 'a030185b-e88b-4e0d-a043-93e4f34c60d6'
          )

          VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
            get("/v0/profile/status/#{transaction.transaction_id}")
            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['data']['type']).to eq('async_transaction_va_profile_address_transactions')
          end
        end
      end

      context 'with a vet360 transaction' do
        it 'responds with a serialized transaction', :aggregate_failures do
          transaction = create(
            :address_transaction,
            user_uuid: user.uuid,
            transaction_id: 'a030185b-e88b-4e0d-a043-93e4f34c60d6'
          )

          VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
            get("/v0/profile/status/#{transaction.transaction_id}")
            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['data']['type']).to eq('async_transaction_vet360_address_transactions')
            # @TODO The ...data.attributes.type has the original, non-snake-cased version of the class
          end
        end
      end
    end

    context 'when the transaction has messages' do
      it 'messages are serialized in the metadata property', :aggregate_failures do
        transaction = create(
          :email_transaction,
          user_uuid: user.uuid,
          transaction_id: 'cb99a754-9fa9-4f3c-be93-ede12c14b68e'
        )

        VCR.use_cassette('va_profile/contact_information/email_transaction_status') do
          get("/v0/profile/status/#{transaction.transaction_id}")
          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body['data']['attributes']['metadata']).to be_a(Array)
        end
      end
    end

    context 'cache invalidation' do
      it 'invalidates the cache for the va-profile-contact-info-response Redis key' do
        VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
          transaction = create(
            :address_transaction,
            user_uuid: user.uuid,
            transaction_id: 'a030185b-e88b-4e0d-a043-93e4f34c60d6'
          )

          expect_any_instance_of(Common::RedisStore).to receive(:destroy)

          get("/v0/profile/status/#{transaction.transaction_id}")
        end
      end
    end
  end

  describe 'GET /v0/profile/status/' do
    context 'when transaction(s) exists' do
      context 'with va profile transactions' do
        it 'responds with an array of transaction(s)', :aggregate_failures do
          create(
            :va_profile_address_transaction,
            user_uuid: user.uuid,
            transaction_id: '0faf342f-5966-4d3f-8b10-5e9f911d07d2'
          )
          create(
            :va_profile_email_transaction,
            user_uuid: user.uuid,
            transaction_id: '786efe0e-fd20-4da2-9019-0c00540dba4d'
          )
          VCR.use_cassette('va_profile/contact_information/address_and_email_transaction_status') do
            get('/v0/profile/status/')
            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['data'].is_a?(Array)).to eq(true)
            expect(response_body['data'][0]['attributes']['type'])
              .to eq('AsyncTransaction::VAProfile::AddressTransaction')
            expect(response_body['data'][1]['attributes']['type'])
              .to eq('AsyncTransaction::VAProfile::EmailTransaction')
          end
        end
      end

      context 'with vet360 transactions' do
        it 'responds with an array of transaction(s)', :aggregate_failures do
          create(
            :address_transaction,
            user_uuid: user.uuid,
            transaction_id: '0faf342f-5966-4d3f-8b10-5e9f911d07d2'
          )
          create(
            :email_transaction,
            user_uuid: user.uuid,
            transaction_id: '786efe0e-fd20-4da2-9019-0c00540dba4d'
          )
          VCR.use_cassette('va_profile/contact_information/address_and_email_transaction_status') do
            get('/v0/profile/status/')
            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['data'].is_a?(Array)).to eq(true)
            expect(response_body['data'][0]['attributes']['type'])
              .to eq('AsyncTransaction::Vet360::AddressTransaction')
            expect(response_body['data'][1]['attributes']['type'])
              .to eq('AsyncTransaction::Vet360::EmailTransaction')
          end
        end
      end
    end

    context 'cache invalidation' do
      context 'when transactions exist' do
        it 'invalidates the cache for the va-profile-contact-info-response Redis key' do
          VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
            create :address_transaction

            expect_any_instance_of(Common::RedisStore).to receive(:destroy)

            get '/v0/profile/status/'
          end
        end
      end

      context 'when transactions do not exist' do
        it 'invalidates the cache for the va-profile-contact-info-response Redis key' do
          allow(AsyncTransaction::Vet360::Base).to receive(:refresh_transaction_statuses).and_return([])

          expect_any_instance_of(Common::RedisStore).to receive(:destroy)

          get '/v0/profile/status/'
        end
      end
    end
  end
end
