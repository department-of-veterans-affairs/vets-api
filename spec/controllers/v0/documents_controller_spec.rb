# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::DocumentsController, type: :controller do
  context 'with no file param' do
    it 'returns unauthorized' do
      post :create, claim_id: 3
      expect(response).to have_http_status(:bad_request)
    end
  end
end
