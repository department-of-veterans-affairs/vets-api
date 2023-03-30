# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/preferred_name'

RSpec.describe 'preferred_name' do
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

  describe 'PUT /v0/profile/preferred_names' do
    context 'with a 200 response' do
      it 'matches the preferred_name schema', :aggregate_failures do
        preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
        VCR.use_cassette('va_profile/demographics/post_preferred_name_success') do
          put('/v0/profile/preferred_names', params: preferred_name.to_json, headers:)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/preferred_name_response')
        end
      end

      it 'returns the correct values', :aggregate_failures do
        preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
        VCR.use_cassette('va_profile/demographics/post_preferred_name_success') do
          put('/v0/profile/preferred_names', params: preferred_name.to_json, headers:)

          json = json_body_for(response)['attributes']['preferred_name']
          expect(response).to have_http_status(:ok)
          expect(json['text']).to eq(preferred_name.text)
          expect(json['source_system_user']).to eq('123498767V234859')
          expect(json['source_date']).to eq('2022-04-08T15:09:23.000Z')
        end
      end
    end

    context 'matches the errors schema' do
      it 'when text is blank', :aggregate_failures do
        preferred_name = VAProfile::Models::PreferredName.new(text: nil)

        put('/v0/profile/preferred_names', params: preferred_name.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "text - can't be blank"
      end

      it 'when text is too long', :aggregate_failures do
        preferred_name = VAProfile::Models::PreferredName.new(text: 'A' * 26)

        put('/v0/profile/preferred_names', params: preferred_name.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include 'text - is too long (maximum is 25 characters)'
      end
    end
  end
end
