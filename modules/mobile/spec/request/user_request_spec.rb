# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe 'user', type: :request do
  describe 'GET /mobile/v0/user' do
    context 'with a user who has a cached iam session' do
      before { iam_sign_in }

      it 'returns returns basic user info without hitting the introspect endpoint' do
        get '/mobile/v0/user', headers: iam_headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(expected_body)
      end
    end
  end
end
