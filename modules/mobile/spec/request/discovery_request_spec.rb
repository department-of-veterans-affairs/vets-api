# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'discovery', type: :request do
  describe 'GET /mobile' do
    before { get '/mobile' }

    it 'returns a 200' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns a welcome message' do
      expect(response.parsed_body).to eq(
        {
          'data' => {
            'attributes' => {
              'message' => 'Welcome to the mobile API'
            }
          }
        }
      )
    end
  end
end
