# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Disability rating', type: :request do
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  before(:each) { stub_mvi }

  it 'shows the disability rating record' do
    VCR.use_cassette('evss/common/rating_record') do
      get '/v0/disability_rating', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to match_response_schema('disability_rating')
    end
  end
end
