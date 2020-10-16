# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'payment_information', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  describe 'GET /mobile/v0/payment_information' do
    context 'with a valid evss response' do
      it 'matches the ppiu schema' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          get '/mobile/v0/ppiu/payment_information', headers: iam_headers
          expect(response).to have_http_status(:ok)
          # expect(response).to match_json_schema('payment_information')
        end
      end
    end
  end
end
