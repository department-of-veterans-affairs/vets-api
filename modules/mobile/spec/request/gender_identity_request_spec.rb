# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require 'va_profile/demographics/service'

RSpec.describe 'gender identity', type: :request do
  include SchemaMatchers

  describe 'logingov user' do
    let(:csd) { 'LGN' }

    before do
      iam_sign_in(FactoryBot.build(:iam_user, :logingov))
      allow_any_instance_of(IAMUser).to receive(:logingov_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    describe 'GET /mobile/v0/gender_identity/edit' do
      context 'requested' do
        before do
          get('/mobile/v0/user/gender_identity/edit', headers: iam_headers_no_camel)
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
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      context 'matches the errors schema' do
        it 'when code is blank', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: nil)

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include "code - can't be blank"
        end

        it 'when code is an invalid option', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'A')

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include 'code - invalid code'
        end
      end
    end
  end

  describe 'idme user' do
    let(:csd) { 'IDM' }

    before do
      iam_sign_in(FactoryBot.build(:iam_user))
      allow_any_instance_of(IAMUser).to receive(:idme_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    describe 'GET /mobile/v0/gender_identity/edit' do
      context 'requested' do
        before do
          get('/mobile/v0/user/gender_identity/edit', headers: iam_headers_no_camel)
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
            put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      context 'matches the errors schema' do
        it 'when code is blank', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: nil)

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include "code - can't be blank"
        end

        it 'when code is an invalid option', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'A')

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
          expect(errors_for(response)).to include 'code - invalid code'
        end
      end
    end
  end

  describe 'unauthorized user' do
    before do
      iam_sign_in(FactoryBot.build(:iam_user, :no_multifactor))
    end

    describe 'GET /mobile/v0/gender_identity/edit' do
      context 'returns 200' do
        it 'returns 200', :aggregate_failures do
          get('/mobile/v0/user/gender_identity/edit', headers: iam_headers_no_camel)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe 'PUT /mobile/v0/gender_identity' do
      context 'returns 403' do
        it 'returns 402', :aggregate_failures do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
