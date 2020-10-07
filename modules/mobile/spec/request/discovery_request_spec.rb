# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe 'discovery', type: :request do
  describe 'GET /mobile' do
    context 'when the mobile_api flipper feature is enabled' do
      let(:expected_body) do
        {
          'data' => {
            'attributes' => {
              'message' => 'Welcome to the mobile API'
            }
          }
        }
      end

      it 'returns the welcome message' do
        get '/mobile'

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(expected_body)
      end
    end

    context 'when the mobile_api flipper feature is disabled' do
      before { Flipper.disable('mobile_api') }

      it 'returns a 404' do
        get '/mobile'

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
