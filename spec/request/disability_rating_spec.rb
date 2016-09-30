# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Disability rating', type: :request do
  it 'shows the disability rating record' do
    VCR.use_cassette('evss/common/rating_record') do
      get '/v0/disability_rating'
      expect(response).to match_response_schema('disability_rating')
    end
  end
end
