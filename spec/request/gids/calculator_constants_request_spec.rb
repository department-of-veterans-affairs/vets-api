# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'calculator_constants', type: :request do
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('gi_client/gets_the_calculator_constants') do
      get '/v0/gi/calculator_constants/'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/calculator_constants')
  end
end
