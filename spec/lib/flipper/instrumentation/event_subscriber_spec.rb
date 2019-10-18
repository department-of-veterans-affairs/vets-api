# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Flipper::Instrumentation::EventSubscriber do
  let(:test_user) { FactoryBot.build(:user) }

  context 'logs changes to toggle values' do
    it 'logs feature calls with result after operation for disable' do
      Flipper.disable(:facility_locator_show_community_cares)
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('facility_locator_show_community_cares')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('boolean')
    end

    it 'logs feature calls with result after operation for disable_percentage_of_actors' do
      Flipper.disable_percentage_of_actors(:facility_locator_show_community_cares)
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('facility_locator_show_community_cares')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('percentage_of_actors')
    end

    it 'logs feature calls with result after operation for disable_percentage_of_time' do
      Flipper.disable_percentage_of_time(:facility_locator_show_community_cares)
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('facility_locator_show_community_cares')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('percentage_of_time')
    end

    it 'logs feature calls with result after operation for enable_percentage_of_actors' do
      Flipper.enable_percentage_of_actors :facility_locator_show_community_cares, 10
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('facility_locator_show_community_cares')
      expect(last_event.operation).to eq('enable')
      expect(last_event.gate_name).to eq('percentage_of_actors')
    end

    it 'logs feature calls with result after operation for enable_percentage_of_time' do
      Flipper.enable_percentage_of_time :facility_locator_show_community_cares, 5
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('facility_locator_show_community_cares')
      expect(last_event.operation).to eq('enable')
      expect(last_event.gate_name).to eq('percentage_of_time')
    end

    it 'logs feature calls with result after operation for enable_actor' do
      Flipper.enable_actor :facility_locator_show_community_cares, test_user
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('facility_locator_show_community_cares')
      expect(last_event.operation).to eq('enable')
      expect(last_event.gate_name).to eq('actor')
    end

    it 'logs feature calls with result after operation for disable_actor' do
      Flipper.disable_actor :facility_locator_show_community_cares, test_user
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('facility_locator_show_community_cares')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('actor')
    end
  end

  context 'does not log evaluation of toggle values' do
    it 'something' do
      expect do
        Flipper.enabled?(:facility_locator_show_community_cares, @current_user)
      end.to change(FeatureToggleEvent, :count).by(0)
    end
  end
end
