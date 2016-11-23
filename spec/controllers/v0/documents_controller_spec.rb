# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::DocumentsController, type: :controller do
  let(:session) { create(:loa3_session) }
  let!(:user) { create(:loa3_user, uuid: session.uuid, session: session) }

  context 'with no file param' do
    it 'returns bad request' do
      request.headers['Authorization'] = "Token token=#{session.token}"
      post :create, disability_claim_id: 3
      expect(response).to have_http_status(:bad_request)
    end
  end
end
