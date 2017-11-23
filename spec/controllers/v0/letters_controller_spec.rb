# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::LettersController, type: :controller do
  include SchemaMatchers

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid) }

  it 'should have a response that matches the schema' do
    VCR.use_cassette('evss/letters/letters') do
      request.headers['Authorization'] = "Token token=#{session.token}"
      get :index
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('letters')
    end
  end
end
