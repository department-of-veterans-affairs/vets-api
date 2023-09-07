# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/helpers/iam_session_helper'
require_relative '../../support/matchers/json_schema_matcher'
require 'common/client/errors'

RSpec.describe 'user', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v2/user' do
    let(:user) { build(:iam_user) }
    let(:attributes) { response.parsed_body.dig('data', 'attributes') }

    before do
      iam_sign_in(user)
      allow_any_instance_of(IAMUser).to receive(:idme_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
      get '/mobile/v2/user', headers: iam_headers
    end

    it 'returns an ok response' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns a user profile response with the expected schema' do
      expect(response.body).to match_json_schema('v2/user')
    end

    it 'includes the users names' do
      expect(attributes['firstName']).to include(user.first_name)
      expect(attributes['middleName']).to include(user.middle_name)
      expect(attributes['lastName']).to include(user.last_name)
    end

    it 'includes the users sign-in email' do
      expect(attributes['signinEmail']).to include(user.email)
    end

    it 'includes sign-in service' do
      expect(attributes['signinService']).to eq('IDME')
    end
  end
end
