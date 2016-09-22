# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::Facilities::VaController, type: :controller do
  context 'with bad service param' do
    it 'returns 400' do
      post :index, services: ['OilChange']
      expect(response).to have_http_status(:bad_request)
    end
  end
end
