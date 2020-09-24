# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DocumentsController, type: :controller do
  context 'with no file param' do
    it 'returns bad request' do
      sign_in
      post :create, params: { evss_claim_id: 3 }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
