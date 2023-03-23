# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/gender_identity'

RSpec.describe 'gender_identity' do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:time) { Time.zone.local(2022, 4, 8, 15, 9, 23) }

  before do
    Timecop.freeze(time)
    sign_in_as(user)
  end

  after do
    Timecop.return
  end

  describe 'PUT /v0/profile/gender_identities' do
    context 'with a 200 response' do
      it 'matches the gender_identity schema', :aggregate_failures do
        gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')
        VCR.use_cassette('va_profile/demographics/post_gender_identity_success') do
          put('/v0/profile/gender_identities', params: gender_identity.to_json, headers:)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/gender_identity_response')
        end
      end

      it 'returns the correct values', :aggregate_failures do
        gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')
        VCR.use_cassette('va_profile/demographics/post_gender_identity_success') do
          put('/v0/profile/gender_identities', params: gender_identity.to_json, headers:)

          json = json_body_for(response)['attributes']['gender_identity']
          expect(response).to have_http_status(:ok)
          expect(json['code']).to eq(gender_identity.code)
          expect(json['name']).to eq(gender_identity.name)
          expect(json['source_system_user']).to eq('123498767V234859')
          expect(json['source_date']).to eq('2022-04-08T15:09:23.000Z')
        end
      end
    end

    context 'matches the errors schema' do
      it 'when code is blank', :aggregate_failures do
        gender_identity = VAProfile::Models::GenderIdentity.new(code: nil)

        put('/v0/profile/gender_identities', params: gender_identity.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "code - can't be blank"
      end

      it 'when code is an invalid option', :aggregate_failures do
        gender_identity = VAProfile::Models::GenderIdentity.new(code: 'A')

        put('/v0/profile/gender_identities', params: gender_identity.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include 'code - invalid code'
      end
    end
  end
end
