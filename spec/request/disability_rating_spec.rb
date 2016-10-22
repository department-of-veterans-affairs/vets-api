# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Disability rating', type: :request do
  let(:user) do
    user = FactoryGirl.build(:mvi_user)
    user.save
    user
  end
  let(:session) do
    session = Session.new(uuid: user.uuid)
    session.save
    session
  end

  it 'shows the disability rating record' do
    VCR.use_cassette('evss/common/rating_record') do
      get '/v0/disability_rating', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to match_response_schema('disability_rating')
    end
  end
end
