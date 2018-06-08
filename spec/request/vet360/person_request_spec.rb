# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'person', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user_with_suffix, :loa3) }

  before do
    Timecop.freeze('2018-04-09T17:52:03Z')
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  after { Timecop.return }

  describe 'POST /v0/profile/initialize_vet360_id' do
    let(:empty_body) do
      {
        bio: {
          sourceDate: Time.zone.now.iso8601
        }
      }.to_json
    end

    before do
      allow_any_instance_of(User).to receive(:vet360_id).and_return(nil)
    end

    context 'with a user that has an icn_with_aaid' do
      it 'should match the transaction response schema', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          post(
            '/v0/profile/initialize_vet360_id',
            empty_body,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'should create a new AsyncTransaction::Vet360::InitializePersonTransaction', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          expect do
            post(
              '/v0/profile/initialize_vet360_id',
              empty_body,
              auth_header.update(
                'Content-Type' => 'application/json', 'Accept' => 'application/json'
              )
            )
          end.to change { AsyncTransaction::Vet360::InitializePersonTransaction.count }.from(0).to(1)
        end
      end
    end

    context 'with an error response' do
      it 'should match the transaction response schema', :aggregate_failures do
        VCR.use_cassette('vet360/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
          post(
            '/v0/profile/initialize_vet360_id',
            empty_body,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end
end
