# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'discovery', type: :request do
  include JsonSchemaMatchers
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
