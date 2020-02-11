# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'permission', type: :request do
  include SchemaMatchers

  let(:user) { build(:vets360_user) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:frozen_time) { Time.zone.local(2019, 11, 5, 16, 49, 18) }

  before do
    Timecop.freeze(frozen_time)
    sign_in_as(user)
    Settings.virtual_hosts << 'www.example.com'
  end

  after do
    Timecop.return
  end

  describe 'POST /v0/profile/permissions' do
    let(:permission) { build(:permission, vet360_id: user.vet360_id, id: nil) }

    context 'with a 200 response' do
      it 'matches the permission schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_permission_success') do
          post('/v0/profile/permissions', params: permission.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::PermissionTransaction db record' do
        VCR.use_cassette('vet360/contact_information/post_permission_success') do
          expect do
            post('/v0/profile/permissions', params: permission.to_json, headers: headers)
          end.to change(AsyncTransaction::Vet360::PermissionTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a 400 response' do
      it 'matches the errors schema', :aggregate_failures do
        permission.id = 401

        VCR.use_cassette('vet360/contact_information/post_permission_w_id_error') do
          post('/v0/profile/permissions', params: permission.to_json, headers: headers)

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a forbidden response' do
        permission.id = 401
        VCR.use_cassette('vet360/contact_information/post_permission_status_403') do
          post('/v0/profile/permissions', params: permission.to_json, headers: headers)

          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe 'PUT /v0/profile/permissions' do
    let(:permission) { build(:permission, vet360_id: user.vet360_id) }

    before { permission.id = 401 }

    context 'with a 200 response' do
      it 'matches the permission schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/put_permission_success') do
          put('/v0/profile/permissions', params: permission.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::PermissionTransaction db record' do
        VCR.use_cassette('vet360/contact_information/put_permission_success') do
          expect do
            put('/v0/profile/permissions', params: permission.to_json, headers: headers)
          end.to change(AsyncTransaction::Vet360::PermissionTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'when effective_end_date is included' do
      let(:permission) do
        build(:permission,
              vet360_id: user.vet360_id,
              effective_end_date: Time.now.utc.iso8601,
              permission_value: true)
      end
      let(:id_in_cassette) { 401 }

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
        permission.id = id_in_cassette
      end

      it 'effective_end_date is NOT included in the request body', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/put_permission_ignore_eed', VCR::MATCH_EVERYTHING) do
          # The cassette we're using does not include the effectiveEndDate in the body.
          # So this test ensures that it was stripped out
          put('/v0/profile/permissions', params: permission.to_json, headers: headers)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end
    end
  end

  describe 'DELETE /v0/profile/permissions' do
    let(:permission) do
      build(:permission, vet360_id: user.vet360_id, source_date: '2019-11-05T16:49:18Z')
    end
    let(:id_in_cassette) { 401 }

    before do
      allow_any_instance_of(User).to receive(:icn).and_return('64762895576664260')
      permission.id = id_in_cassette
    end

    context 'when the method is DELETE' do
      it 'effective_end_date gets appended to the request body', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/delete_permission_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete('/v0/profile/permissions', params: permission.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end
    end
  end
end
