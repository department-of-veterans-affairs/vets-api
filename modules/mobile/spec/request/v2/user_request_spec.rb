# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/helpers/sis_session_helper'
require_relative '../../support/matchers/json_schema_matcher'
require 'common/client/errors'

RSpec.describe 'user', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v2/user' do
    let!(:user) { sis_user(idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }
    let(:attributes) { response.parsed_body.dig('data', 'attributes') }

    before do
      get '/mobile/v2/user', headers: sis_headers
    end

    it 'returns an ok response' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns a user profile response with the expected schema' do
      expect(response.body).to match_json_schema('v2/user')
    end

    it 'includes the users names' do
      expect(attributes['firstName']).to eq(user.first_name)
      expect(attributes['middleName']).to eq(user.middle_name)
      expect(attributes['lastName']).to eq(user.last_name)
    end

    it 'eqs the users sign-in email' do
      expect(attributes['signinEmail']).to eq(user.email)
    end

    it 'includes the user\'s birth_date' do
      expect(attributes['birthDate']).to eq(Date.parse(user.birth_date).iso8601)
    end

    it 'includes sign-in service' do
      expect(attributes['signinService']).to eq('idme')
    end
  end
end
