# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claim Appeals API endpoint', type: :request do
  context 'with the X-VA-SSN header supplied ' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get '/services/appeals/v0/appeals', nil, 'X-VA-SSN' => "111223333"
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
#        expect(response).to match_response_schema('appeals')
      end
    end
  end

  context 'without the X-VA-SSN header supplied ' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get '/services/appeals/v0/appeals'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
