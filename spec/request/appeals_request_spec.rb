# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Appeals Status', type: :request do
  let(:user) { FactoryGirl.create(:loa3_user, ssn: '796126859') }
  let(:session) { Session.create(uuid: user.uuid) }

  context 'for a user with data in the mocks' do
    it 'returns a 403' do
      get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('appeals')
    end
  end
end
