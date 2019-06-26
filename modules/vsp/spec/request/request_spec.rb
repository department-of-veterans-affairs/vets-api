# frozen_string_literal: true

require 'rails_helper'
require 'rspec/json_expectations'

RSpec.describe 'vsp', type: :request do
  describe 'GET /v0/hello_world' do
    context 'with a valid response' do
      # let(:message) { response.body.dig('data', 'attributes', 'message') }
      it 'should match the vsp hello_world schema' do
        VCR.use_cassette('vsp/get_message') do
          get '/vsp/v0/hello_world'
          expect(response).to have_http_status(:ok)
          expect(response.body).to include_json(
            data: {
              attributes: {
                message: 'Welcome to the vets.gov API'
              }
            }
          )
        end
      end
    end
  end
end
