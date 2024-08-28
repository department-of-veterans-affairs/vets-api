# frozen_string_literal: true

require_relative '../support/helpers/rails_helper'
require 'va_profile/demographics/service'

RSpec.describe 'gender identity', type: :request do
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

        it 'returns a list of valid ids' do
          json = json_body_for(response)['attributes']['options']
          expect(json).to eq(VAProfile::Models::GenderIdentity::OPTIONS)
        end

        it 'returns a list in correct order' do
          codes = response.parsed_body.dig('data', 'attributes', 'options').keys
          expect(codes).to eq(%w[M B TM TF F N O])
        end
      end
    end

    describe 'PUT /mobile/v0/gender_identity' do
      context 'when a valid code is provided' do
        it 'returns a 201' do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          VCR.use_cassette('mobile/va_profile/post_gender_identity_success', erb: { csd: }) do
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      context 'matches the errors schema' do
        it 'when code is blank', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: nil)

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include "code - can't be blank"
        end

        it 'when code is an invalid option', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'A')

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include 'code - invalid code'
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

        it 'returns a list of valid ids' do
          json = json_body_for(response)['attributes']['options']
          expect(json).to eq(VAProfile::Models::GenderIdentity::OPTIONS)
        end

        it 'returns a list in correct order' do
          codes = response.parsed_body.dig('data', 'attributes', 'options').keys
          expect(codes).to eq(%w[M B TM TF F N O])
        end
      end
    end

    describe 'PUT /mobile/v0/gender_identity' do
      context 'when a valid code is provided' do
        it 'returns a 201' do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          VCR.use_cassette('mobile/va_profile/post_gender_identity_success', erb: { csd: }) do
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      context 'matches the errors schema' do
        it 'when code is blank', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: nil)

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include "code - can't be blank"
        end

        it 'when code is an invalid option', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'A')

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: sis_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include 'code - invalid code'
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
