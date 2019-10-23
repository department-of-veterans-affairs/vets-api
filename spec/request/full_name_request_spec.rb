# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'full_name', type: :request do
  include SchemaMatchers

  before do
    sign_in_as(build(:user_with_suffix, :loa3))
  end

  describe 'GET /v0/profile/full_name' do
    context 'with a 200 response' do
      it 'matches the full name schema' do
        get '/v0/profile/full_name'

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('full_name_response')
      end
    end
  end
end
