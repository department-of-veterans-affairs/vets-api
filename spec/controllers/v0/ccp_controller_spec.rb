# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Facilities::CcpController, type: :controller do
  regex_matcher = lambda { |r1, r2|
    r1.uri.match(r2.uri)
  }

  it 'should have a certain shape' do
    VCR.use_cassette('facilities/va/ppms', match_requests_on: [regex_matcher]) do
      get 'show', id: 'ccp_12345'
      expect(response).to have_http_status(:ok)
      bod = JSON.parse(response.body)
      expect(bod['data']['id']).to include('ccp_')
      expect(bod['data']['type']).to eq('cc_provider')
    end
  end

  it 'should indicate an invalid parameter' do
    get 'show', id: '12345'
    expect(response).to have_http_status(400)
    bod = JSON.parse(response.body)
    expect(bod['errors'].length).to be > 0
    expect(bod['errors'][0]['title']).to eq('Invalid field value')
  end

  it 'should return some specialties' do
    VCR.use_cassette('facilities/va/ppms', match_requests_on: [regex_matcher]) do
      get 'services'
      expect(response).to have_http_status(:ok)
      bod = JSON.parse(response.body)
      expect(bod.length).to be > 0
      expect(bod[0]['SpecialtyCode'].length).to be > 0
    end
  end
end
