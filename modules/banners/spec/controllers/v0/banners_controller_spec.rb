# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BannersController, type: :controller do
  describe 'GET #by_path' do
    let(:path) { '/sample/path' }
    let(:banner_type) { 'full_width_banner_alert' }

    # Create banners that should match the query
    let!(:matching_banner) do
      create(:banner, entity_bundle: banner_type, context: [{ entity: { entityUrl: { path: } } }])
    end
    let!(:non_matching_banner) do
      create(:banner, entity_bundle: 'different_type', context: [{ entity: { entityUrl: { path: '/other/path' } } }])
    end

    it 'returns banners matching the specified path and banner type' do
      get :by_path, params: { path:, type: banner_type }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)

      # Ensure only the matching banner is returned
      expect(json_response['banners'].length).to eq(1)
      expect(json_response['banners'][0]['id']).to eq(matching_banner.id)
    end

    it 'returns an empty array if no banners match the criteria' do
      get :by_path, params: { path: '/nonexistent/path', type: 'nonexistent_type' }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)

      expect(json_response['banners']).to eq([])
    end
  end
end
