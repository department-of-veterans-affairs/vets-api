# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'profile reference data', type: :request do
  include SchemaMatchers

  before do
    sign_in
  end

  %i[countries states zipcodes].each do |endpoint|
    describe "GET /v0/profile/reference_data/#{endpoint}" do
      it 'should match the schema' do
        VCR.use_cassette("vet360/reference_data/#{endpoint}") do
          get("/v0/profile/reference_data/#{endpoint}", params: nil)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema("vet360/#{endpoint}")
        end
      end
    end
  end
end
