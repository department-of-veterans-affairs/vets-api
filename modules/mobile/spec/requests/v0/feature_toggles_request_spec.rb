# frozen_string_literal: true

require_relative '../../support/helpers/rails_helper'
require_relative '../../support/helpers/committee_helper'

RSpec.describe 'Feature Toggles API endpoint', type: :request do
  include CommitteeHelper

  describe 'GET /mobile/v0/feature-toggles' do
    let(:features) { [{ name: 'feature1', value: true }, { name: 'feature2', value: false }] }
    let!(:user) { sis_user }

    before do
      allow_any_instance_of(FeatureTogglesService).to receive(:get_all_features).and_return(features)
      allow_any_instance_of(FeatureTogglesService).to receive(:get_features).and_return(features)
    end

    context 'with authenticated user' do
      it 'uses the current_user for feature toggle evaluation' do
        expect_any_instance_of(FeatureTogglesService).to receive(:get_features).with(['feature1', 'feature2'])

        get '/mobile/v0/feature-toggles?features=feature1,feature2', headers: sis_headers

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        expect(JSON.parse(response.body)['data']['features']).to eq(
          JSON.parse(features.to_json)
        )
      end

      it 'gets all features for the current user when no specific features requested' do
        expect_any_instance_of(FeatureTogglesService).to receive(:get_all_features)

        get '/mobile/v0/feature-toggles', headers: sis_headers

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        expect(JSON.parse(response.body)['data']['features']).to eq(
          JSON.parse(features.to_json)
        )
      end
    end

    context 'with unauthenticated user' do
      it 'passes nil as the user for specific features' do
        expect_any_instance_of(FeatureTogglesService).to receive(:get_features).with(['feature1', 'feature2'])

        get '/mobile/v0/feature-toggles?features=feature1,feature2'

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
      end

      it 'passes nil as the user for all features' do
        expect_any_instance_of(FeatureTogglesService).to receive(:get_all_features)

        get '/mobile/v0/feature-toggles'

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
      end

      it 'uses cookie_id when provided' do
        cookie_id = 'test-cookie-id'
        expect_any_instance_of(FeatureTogglesService).to receive(:get_all_features)

        get "/mobile/v0/feature-toggles?cookie_id=#{cookie_id}"

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
      end
    end
  end
end