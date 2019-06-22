# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'vsp', type: :request do
  # include SchemaMatchers

  describe 'GET /v0/hello_world' do
    context 'with a valid response' do
      it 'should match the vsp hello_world schema' do
        VCR.use_cassette('vsp/get_message') do
          get '/v0/vsp/hello_world'
          expect(response).to have_http_status(:ok)
          # expect(response).to match_response_schema('hello_world')
        end
      end
    end
  end
end
