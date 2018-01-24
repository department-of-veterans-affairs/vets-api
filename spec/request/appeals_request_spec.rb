# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appeals Status', type: :request do
  include SchemaMatchers

  let(:session) { Session.create(uuid: user.uuid) }

  context 'loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1, ssn: '111223333') }

    it 'returns a forbidden error' do
      get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'loa3 user in the mocks' do
    let(:user) { FactoryBot.create(:user, :loa3, ssn: '111223333') }

    it 'returns a successful response' do
      get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('appeals')
    end
  end
end
