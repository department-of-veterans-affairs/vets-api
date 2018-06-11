# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'email_address', type: :request do
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

  describe 'POST /v0/profile/email_addresses' do
    let(:email) { build(:email, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'should match the email address schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_email_success') do
          post(
            '/v0/profile/email_addresses',
            { email_address: 'test@example.com' }.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::EmailTransaction db record' do
        VCR.use_cassette('vet360/contact_information/post_email_success') do
          expect do
            post(
              '/v0/profile/email_addresses',
              { email_address: 'test@example.com' }.to_json,
              auth_header.update(
                'Content-Type' => 'application/json', 'Accept' => 'application/json'
              )
            )
          end.to change(AsyncTransaction::Vet360::EmailTransaction, :count).from(0).to(1)
        end
      end

      it 'invalidates the cache for the vet360-contact-info-response Redis key' do
        VCR.use_cassette('vet360/contact_information/post_email_success') do
          expect_any_instance_of(Common::RedisStore).to receive(:destroy)

          post(
            '/v0/profile/email_addresses',
            { email_address: 'test@example.com' }.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )
        end
      end
    end

    context 'with a 400 response' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_email_w_id_error') do
          post(
            '/v0/profile/email_addresses',
            { id: 42, email_address: 'person42@example.com' }.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'should not invalidate the cache' do
        VCR.use_cassette('vet360/contact_information/post_email_w_id_error') do
          expect_any_instance_of(Common::RedisStore).to_not receive(:destroy)

          post(
            '/v0/profile/email_addresses',
            { id: 42, email_address: 'person42@example.com' }.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a forbidden response' do
        VCR.use_cassette('vet360/contact_information/post_email_status_403') do
          post(
            '/v0/profile/email_addresses',
            { email_address: 'test@example.com' }.to_json,
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
        post(
          '/v0/profile/email_addresses',
          { email_address: '' }.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "email-address - can't be blank"
      end
    end
  end

  describe 'PUT /v0/profile/email_addresses' do
    let(:email) { build(:email, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'should match the email address schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/put_email_success') do
          put(
            '/v0/profile/email_addresses',
            { id: 42, email_address: 'person42@example.com' }.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::EmailTransaction db record' do
        VCR.use_cassette('vet360/contact_information/put_email_success') do
          expect do
            put(
              '/v0/profile/email_addresses',
              { id: 42, email_address: 'person42@example.com' }.to_json,
              auth_header.update(
                'Content-Type' => 'application/json', 'Accept' => 'application/json'
              )
            )
          end.to change(AsyncTransaction::Vet360::EmailTransaction, :count).from(0).to(1)
        end
      end

      it 'invalidates the cache for the vet360-contact-info-response Redis key' do
        VCR.use_cassette('vet360/contact_information/put_email_success') do
          expect_any_instance_of(Common::RedisStore).to receive(:destroy)

          put(
            '/v0/profile/email_addresses',
            { id: 42, email_address: 'person42@example.com' }.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )
        end
      end
    end

    context 'with a validation issue' do
      it 'should match the errors schema', :aggregate_failures do
        put(
          '/v0/profile/email_addresses',
          { email_address: '' }.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "email-address - can't be blank"
      end
    end
  end

  describe 'DELETE /v0/profile/email_addresses' do
    let(:email) do
      build(:email, vet360_id: user.vet360_id, email_address: 'person103@example.com')
    end

    before do
      allow_any_instance_of(User).to receive(:icn).and_return('64762895576664260')
      email.id = 42
    end

    context 'with a 200 response from the service' do
      it 'should match the transaction response schema', aggregate_failures: true, focus: true do
        VCR.use_cassette('vet360/contact_information/delete_email_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete(
            '/v0/profile/email_addresses',
            email.to_json,
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
