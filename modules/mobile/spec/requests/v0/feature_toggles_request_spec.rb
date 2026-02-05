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
      Flipper.enable(@feature_name) # rubocop:disable Project/ForbidFlipperToggleInSpecs

      @second_feature = 'this_is_only_a_test_two'
      @second_feature_camel = @second_feature.camelize(:lower)
      Flipper.enable(@second_feature) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    after(:all) do
      Flipper.disable(@feature_name) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      Flipper.disable(@second_feature) # rubocop:disable Project/ForbidFlipperToggleInSpecs
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
        Flipper.disable(@feature_name) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        Flipper.enable_actor(@feature_name, user) # rubocop:disable Project/ForbidFlipperToggleInSpecs

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

      it 'gets only the requested features when features parameter is provided' do
        get "/mobile/v0/feature-toggles?features=#{@feature_name}", headers: sis_headers

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        parsed_features = JSON.parse(response.body)['data']['features']
        expect(parsed_features.length).to eq(1)
        expect(parsed_features.first['name']).to eq(@feature_name)
        expect(parsed_features.first['value']).to be(true)
      end

      it 'gets multiple requested features when comma-separated' do
        get "/mobile/v0/feature-toggles?features=#{@feature_name},#{@second_feature}", headers: sis_headers

        expect(response).to have_http_status(:ok)
        assert_schema_conform(200)
        parsed_features = JSON.parse(response.body)['data']['features']
        expect(parsed_features.length).to eq(2)
        expect(parsed_features.map { |f| f['name'] }).to include(@feature_name, @second_feature)
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

    context 'when features.yml contains feature gates' do
      it 'includes both snake_case and camelCase versions of feature names' do
        get '/mobile/v0/feature-toggles'

        expect(response).to have_http_status(:ok)
        parsed_features = JSON.parse(response.body)['data']['features']

        # Check both formats exist
        expect(parsed_features.map { |f| f['name'] }).to include(@feature_name)
        expect(parsed_features.map { |f| f['name'] }).to include(@feature_name_camel)
        expect(parsed_features.map { |f| f['name'] }).to include(@second_feature)
        expect(parsed_features.map { |f| f['name'] }).to include(@second_feature_camel)
      end
    end
  end
end
