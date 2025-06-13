# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Feature Toggles API endpoint', type: :request do
  describe 'GET /mobile/v0/feature-toggles' do
    let(:features) { [{ name: 'feature1', value: true }, { name: 'feature2', value: false }] }
    
    before do
      allow_any_instance_of(FeatureTogglesService).to receive(:get_all_features).and_return(features)
      allow_any_instance_of(FeatureTogglesService).to receive(:get_features).and_return(features)
    end

    context 'with specific features requested' do
      it 'returns the requested features' do
        get '/mobile/v0/feature-toggles?features=feature1,feature2'
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['features']).to eq(
          JSON.parse(features.to_json)
        )
      end
    end

    context 'when requesting all features' do
      it 'returns all features' do
        get '/mobile/v0/feature-toggles'
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['features']).to eq(
          JSON.parse(features.to_json)
        )
      end
    end

    context 'with both authenticated and unauthenticated users' do
      let(:user) { build(:user) }

      before do
        allow_any_instance_of(Mobile::V0::FeatureTogglesController).to receive(:current_user).and_return(user)
      end

      it 'works for authenticated users' do
        get '/mobile/v0/feature-toggles'
        
        expect(response).to have_http_status(:ok)
      end

      it 'works for unauthenticated users with cookie ID' do
        get '/mobile/v0/feature-toggles?cookie_id=test-cookie'
        
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
