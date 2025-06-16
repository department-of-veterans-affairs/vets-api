# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::FeatureTogglesController, type: :controller do
  describe '#index' do
    let(:features) { [{ name: 'feature1', value: true }, { name: 'feature2', value: false }] }
    let(:service) { instance_double(FeatureTogglesService) }

    before do
      allow(FeatureTogglesService).to receive(:new).and_return(service)
    end

    context 'with specific features requested' do
      before do
        allow(service).to receive(:get_features).with(%w[feature1 feature2]).and_return(features)
        get :index, params: { features: 'feature1,feature2' }
      end

      it 'returns HTTP success' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the requested features' do
        expect(JSON.parse(response.body)['data']['features']).to eq(
          JSON.parse(features.to_json)
        )
      end
    end

    context 'when requesting all features' do
      before do
        allow(service).to receive(:get_all_features).and_return(features)
        get :index
      end

      it 'returns HTTP success' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns all features' do
        expect(JSON.parse(response.body)['data']['features']).to eq(
          JSON.parse(features.to_json)
        )
      end
    end

    context 'with both authenticated and unauthenticated users' do
      let(:user) { create(:user) }

      it 'works for authenticated users' do
        allow(controller).to receive(:current_user).and_return(user)
        allow(controller).to receive(:load_user)
        allow(service).to receive(:get_all_features).and_return(features)

        get :index

        expect(FeatureTogglesService).to have_received(:new).with(current_user: user, cookie_id: nil)
        expect(response).to have_http_status(:ok)
      end

      it 'works for unauthenticated users with cookie ID' do
        allow(controller).to receive(:current_user).and_return(nil)
        allow(controller).to receive(:load_user)
        allow(service).to receive(:get_all_features).and_return(features)

        get :index, params: { cookie_id: 'test-cookie' }

        expect(FeatureTogglesService).to have_received(:new).with(current_user: nil, cookie_id: 'test-cookie')
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
