# frozen_string_literal: true

require_relative '../../support/helpers/rails_helper'
require_relative '../../support/helpers/committee_helper'

RSpec.describe 'Feature Toggles API endpoint', type: :request do
  include CommitteeHelper

  describe 'GET /mobile/v0/feature-toggles' do
    let!(:user) { sis_user }
    let(:feature_toggles_service) { FeatureTogglesService.new(current_user: user) }

    before(:all) do
      @feature_name = 'this_is_only_a_test'
      @feature_name_camel = @feature_name.camelize(:lower)
      @cached_enabled_val = Flipper.enabled?(@feature_name)
      Flipper.enable(@feature_name)
    end

    after(:all) do
      Flipper.disable(@feature_name)
    end

    context 'with authenticated user' do
      it 'gets all features for the current user when no specific features requested' do
        get '/mobile/v0/feature-toggles', headers: sis_headers

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        # assert feature values
        parsed_features = JSON.parse(response.body)['data']['features']
        feature_toggle = parsed_features.find { |f| f['name'] == @feature_name }
        expect(feature_toggle['value']).to be(true)
      end

      it 'uses the current_user for feature toggle evaluation' do
        Flipper.disable(@feature_name)
        Flipper.enable_actor(@feature_name, user)

        # retrieve features anonymously
        get '/mobile/v0/feature-toggles'
        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        parsed_features = JSON.parse(response.body)['data']['features']
        feature_toggle = parsed_features.find { |f| f['name'] == @feature_name }
        expect(feature_toggle['value']).to be(false)

        # retrieve features as the user
        get '/mobile/v0/feature-toggles', headers: sis_headers
        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        parsed_features = JSON.parse(response.body)['data']['features']
        feature_toggle = parsed_features.find { |f| f['name'] == @feature_name }
        expect(feature_toggle['value']).to be(true)
      end
    end

    context 'with unauthenticated user' do
      it 'passes nil as the user for all features' do
        get '/mobile/v0/feature-toggles'

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        parsed_features = JSON.parse(response.body)['data']['features']
        feature_toggle = parsed_features.find { |f| f['name'] == @feature_name }
        expect(feature_toggle['value']).to be(true)
      end
    end
  end
end
