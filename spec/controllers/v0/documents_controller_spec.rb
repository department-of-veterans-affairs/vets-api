# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DocumentsController, type: :controller do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid) }

  context 'with no file param' do
    it 'returns bad request' do
      request.headers['Authorization'] = "Token token=#{session.token}"
      post :create, evss_claim_id: 3
      expect(response).to have_http_status(:bad_request)
    end
  end
end
