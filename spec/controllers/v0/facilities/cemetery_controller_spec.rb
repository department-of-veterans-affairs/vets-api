# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::Facilities::CemeteryController, type: :controller do
  context 'with bad bbox param' do
    it 'returns 400' do
      post :index, bbox: 'everywhere'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400' do
      post :index, bbox: '-90,180,45,80'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400' do
      post :index, bbox: ['-45', '-45', '45', '45', '100']
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400' do
      post :index, bbox: ['-45', '-45', '45']
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400' do
      post :index, bbox: ['-45', '-45', '45', 'abc']
      expect(response).to have_http_status(:bad_request)
    end
  end
end
