# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claims', type: :request do
  let(:veteran_id) { ClaimsApi::V2::Veterans::ClaimsController::ICN_FOR_TEST_USER }
  let(:path) { "/services/benefits/v2/veterans/#{veteran_id}/claims" }
  let(:headers) { { 'Authorization': 'Bearer somerandomstuff' } }

  describe 'Claims' do
    context 'auth header' do
      context 'when provided' do
        it 'returns a 200' do
          get path, headers: headers

          expect(response.status).to eq(200)
        end
      end

      context 'when not provided' do
        let(:headers) { nil }

        it 'returns a 401 error code' do
          get path, headers: headers
          expect(response.status).to eq(401)
        end
      end
    end

    context 'veteran_id param' do
      context 'when not provided' do
        let(:veteran_id) { nil }

        it 'returns a 404 error code' do
          get path, headers: headers
          expect(response.status).to eq(404)
        end
      end

      context 'when test veteran_id is provided' do
        it 'returns a 200' do
          get path, headers: headers
          expect(response.status).to eq(200)
        end
      end

      context 'when a non test veteran_id is provided' do
        let(:veteran_id) { '123456789' }

        it 'returns a 404 error code' do
          get path, headers: headers
          expect(response.status).to eq(404)
        end
      end
    end
  end
end
