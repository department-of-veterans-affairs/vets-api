# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'transactions' do
  include SchemaMatchers

  let(:user) { build(:user, :loa3, vet360_id: 1) }

  before do
    allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
    user.vet360_contact_info
    sign_in_as(user)
  end

  describe 'GET /v0/profile/status/:transaction_id' do
    before do
      Timecop.freeze('2024-08-28T18:51:06Z')
    end

    after do
      Timecop.return
    end

    context 'when the requested transaction exists' do
      context 'with a va profile transaction' do
        it 'responds with a serialized transaction', :aggregate_failures do
          transaction = create(
            :va_profile_address_transaction,
            user_uuid: user.uuid,
            transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4'
          )

          VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
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
            transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4'
          )

          VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
            get("/v0/profile/status/#{transaction.transaction_id}")
            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['data']['type']).to eq('async_transaction_va_profile_address_transactions')
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
          transaction_id: '5b4550b3-2bcb-4fef-8906-35d0b4b310a8'
        )

        VCR.use_cassette('va_profile/v2/contact_information/email_transaction_status') do
          get("/v0/profile/status/#{transaction.transaction_id}")
          expect(response).to have_http_status(:ok)
          response_body = JSON.parse(response.body)
          expect(response_body['data']['attributes']['metadata']).to be_a(Array)
        end
      end
    end

    context 'cache invalidation' do
      it 'invalidates the cache for the va-profile-2-contact-info-response Redis key' do
        VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
          transaction = create(
            :address_transaction,
            user_uuid: user.uuid,
            transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4'
          )

          expect_any_instance_of(Common::RedisStore).to receive(:destroy)

          get("/v0/profile/status/#{transaction.transaction_id}")
        end
      end
    end
  end

  describe 'GET /v0/profile/status/' do
    let(:user) { build(:user, :loa3) }

    context 'when transaction(s) exists' do
      context 'with va profile transactions' do
        it 'responds with an array of transaction(s)', :aggregate_failures do
          create(
            :va_profile_address_transaction,
            user_uuid: user.uuid,
            transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4'
          )
          create(
            :va_profile_email_transaction,
            user_uuid: user.uuid,
            transaction_id: '5b4550b3-2bcb-4fef-8906-35d0b4b310a8'
          )
          VCR.use_cassette('va_profile/v2/contact_information/address_and_email_transaction_status') do
            get('/v0/profile/status/')
            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['data'].is_a?(Array)).to be(true)
            expect(response_body['data'][0]['attributes']['type'])
              .to eq('AsyncTransaction::VAProfile::AddressTransaction')
            expect(response_body['data'][1]['attributes']['type'])
              .to eq('AsyncTransaction::VAProfile::EmailTransaction')
          end
        end
      end
    end
  end
end
