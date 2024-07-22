# frozen_string_literal: true

require_relative '../support/helpers/rails_helper'

RSpec.describe 'enrollment status', type: :request do
  let!(:user) { sis_user }

  describe 'GET /mobile/v0/enrollment-status' do
    context 'with an loa3 user' do
      it 'returns ok with enrollment status information' do
        VCR.use_cassette('hca/ee/lookup_user', erb: true) do
          get('/mobile/v0/enrollment-status', headers: sis_headers)
        end

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to match(
          {
            data: {
              id: UUID_REGEX,
              type: 'enrollment_status',
              attributes: {
                status: 'enrolled'
              }
            }
          }
        )
      end
    end

    context 'with a non-loa3 user' do
      let!(:user) { sis_user(:api_auth, :loa1) }

      it 'returns unauthorized' do
        get('/mobile/v0/enrollment-status', headers: sis_headers)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user has no icn' do
      let!(:user) { sis_user(:api_auth, icn: nil) }

      it 'returns not found' do
        get('/mobile/v0/enrollment-status', headers: sis_headers)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
