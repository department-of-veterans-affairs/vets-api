# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require 'va_profile/demographics/service'

# NOTE: Endpoints remain for backwards compatibility with mobile clients. They should be removed in the future.

RSpec.describe 'Mobile::V0::User::GenderIdentity', type: :request do
  include SchemaMatchers

  describe 'logingov user' do
    let!(:user) do
      sis_user(
        icn: '1008596379V859838',
        idme_uuid: nil,
        logingov_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
        authn_context: 'dslogon_loa3'
      )
    end
    let(:csd) { 'LGN' }

    describe 'GET /mobile/v0/gender_identity/edit' do
      context 'requested' do
        before do
          get('/mobile/v0/user/gender_identity/edit', headers: sis_headers(camelize: false))
        end

        it 'returns an empty object' do
          json = json_body_for(response)['attributes']['options']
          expect(json).to eq({})
        end
      end
    end

    describe 'PUT /mobile/v0/gender_identity' do
      context 'when a valid code is provided' do
        it 'returns a 410' do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          VCR.use_cassette('mobile/va_profile/post_gender_identity_success', erb: { csd: }) do
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
            expect(response).to have_http_status(:gone)
          end
        end

        it 'matches the errors schema' do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          VCR.use_cassette('mobile/va_profile/post_gender_identity_success', erb: { csd: }) do
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
            expect(response).to match_response_schema('errors')
            expect(errors_for(response)).to include 'This field no longer exists and cannot be updated'
          end
        end
      end
    end
  end

  describe 'idme user' do
    let!(:user) { sis_user(icn: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }
    let(:csd) { 'IDM' }

    describe 'GET /mobile/v0/gender_identity/edit' do
      context 'requested' do
        before do
          get('/mobile/v0/user/gender_identity/edit', headers: sis_headers(camelize: false))
        end

        it 'returns empty object' do
          json = json_body_for(response)['attributes']['options']
          expect(json).to eq({})
        end
      end
    end

    describe 'PUT /mobile/v0/gender_identity' do
      context 'when a valid code is provided' do
        it 'returns a 410' do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          VCR.use_cassette('mobile/va_profile/post_gender_identity_success', erb: { csd: }) do
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
            expect(response).to have_http_status(:gone)
          end
        end

        it 'matches the errors schema' do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          VCR.use_cassette('mobile/va_profile/post_gender_identity_success', erb: { csd: }) do
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
            expect(response).to match_response_schema('errors')
            expect(errors_for(response)).to include 'This field no longer exists and cannot be updated'
          end
        end
      end
    end
  end

  describe 'unauthorized user' do
    describe 'GET /mobile/v0/gender_identity/edit' do
      context 'without mpi acceess' do
        let!(:user) do
          sis_user(icn: nil, ssn: nil)
        end

        it 'returns 403', :aggregate_failures do
          get('/mobile/v0/user/gender_identity/edit', headers: sis_headers(camelize: false))
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'PUT /mobile/v0/gender_identity' do
      context 'without demographics access' do
        let!(:user) do
          sis_user(idme_uuid: nil, logingov_uuid: nil)
        end

        it 'returns 403', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'without mpi access' do
        let!(:user) do
          sis_user(icn: nil, ssn: nil)
        end

        it 'returns 403', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
