# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'email_address', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
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
    end
  end
end
