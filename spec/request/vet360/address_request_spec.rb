# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'address', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Timecop.freeze(Time.zone.local(2018, 6, 6, 15, 35, 55))
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  after do
    Timecop.return
  end

  describe 'POST /v0/profile/addresses' do
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'should match the address schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_success') do
          post(
            '/v0/profile/addresses',
            address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::AddressTransaction db record' do
        VCR.use_cassette('vet360/contact_information/post_address_success') do
          expect do
            post(
              '/v0/profile/addresses',
              address.to_json,
              auth_header.update(
                'Content-Type' => 'application/json', 'Accept' => 'application/json'
              )
            )
          end.to change(AsyncTransaction::Vet360::AddressTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a 400 response' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_w_id_error') do
          post(
            '/v0/profile/addresses',
            address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a forbidden response' do
        VCR.use_cassette('vet360/contact_information/post_address_status_403') do
          post(
            '/v0/profile/addresses',
            address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a validation issue' do
      it 'should match the errors schema', :aggregate_failures do
        address.address_pou = ''

        post(
          '/v0/profile/addresses',
          address.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "address-pou - can't be blank"
      end
    end
  end

  describe 'PUT /v0/profile/addresses' do
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'should match the email address schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/put_address_success') do
          put(
            '/v0/profile/addresses',
            address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::AddressTransaction db record' do
        VCR.use_cassette('vet360/contact_information/put_address_success') do
          expect do
            put(
              '/v0/profile/addresses',
              address.to_json,
              auth_header.update(
                'Content-Type' => 'application/json', 'Accept' => 'application/json'
              )
            )
          end.to change(AsyncTransaction::Vet360::AddressTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a validation issue' do
      it 'should match the errors schema', :aggregate_failures do
        address.address_pou = ''

        put(
          '/v0/profile/addresses',
          address.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "address-pou - can't be blank"
      end
    end

    context 'when effective_end_date is included' do
      let(:address) do
        build(:vet360_address,
              vet360_id: user.vet360_id,
              effective_end_date: Time.now.utc.iso8601)
      end

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
        address.id = 42
      end

      it 'effective_end_date is ignored', aggregate_failures: true, focus: true do
        VCR.use_cassette('vet360/contact_information/put_address_ignore_eed', VCR::MATCH_EVERYTHING) do
          # The cassette we're using does not include the effectiveEndDate in the body.
          # So this test ensures that it was stripped out
          put(
            '/v0/profile/addresses',
            address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end
    end
  end

  describe 'DELETE /v0/profile/addresses' do
    let(:address) do
      build(:vet360_address, vet360_id: user.vet360_id)
    end

    before do
      allow_any_instance_of(User).to receive(:icn).and_return('64762895576664260')
      address.id = 42
    end

    context 'with a 200 response from the service' do
      it 'should match the transaction response schema', aggregate_failures: true do
        VCR.use_cassette('vet360/contact_information/delete_address_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete(
            '/v0/profile/addresses',
            address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end
    end
  end
end
