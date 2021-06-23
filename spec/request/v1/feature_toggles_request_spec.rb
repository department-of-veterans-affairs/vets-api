# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FeatureToggles', type: :request do
  let(:all_hash) do
    {
      'foo_bar_feature' => { 'actor_type' => 'user' },
      'my_new_feature' => { 'actor_type' => 'cookie_id' },
      'another_great_feature' => { 'actor_type' => 'user' }
    }
  end

  before do
    allow_any_instance_of(FeatureToggles::Factory).to receive(:features_hash).and_return(all_hash)
    allow_any_instance_of(FeatureToggles::Factory).to receive(:enabled?).and_return(true)
  end

  describe 'GET `index`' do
    context 'with feature params' do
      let(:select_features) do
        {
          'data' => {
            'type' => 'feature_toggles',
            'features' => [
              { 'name' => 'fooBarFeature', 'value' => true },
              { 'name' => 'foo_bar_feature', 'value' => true },
              { 'name' => 'myNewFeature', 'value' => true },
              { 'name' => 'my_new_feature', 'value' => true }
            ]
          }
        }
      end

      it 'returns the selected features' do
        get '/v1/feature_toggles?features=foo_bar_feature,myNewFeature'

        expect(JSON.parse(response.body)).to eq(select_features)
      end
    end

    context 'without feature params' do
      let(:all_features) do
        {
          'data' => {
            'type' => 'feature_toggles',
            'features' => [
              { 'name' => 'fooBarFeature', 'value' => true },
              { 'name' => 'foo_bar_feature', 'value' => true },
              { 'name' => 'myNewFeature', 'value' => true },
              { 'name' => 'my_new_feature', 'value' => true },
              { 'name' => 'anotherGreatFeature', 'value' => true },
              { 'name' => 'another_great_feature', 'value' => true }
            ]
          }
        }
      end

      it 'returns all features' do
        get '/v1/feature_toggles'

        expect(JSON.parse(response.body)).to eq(all_features)
      end
    end
  end
end
