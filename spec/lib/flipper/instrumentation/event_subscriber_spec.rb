# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Flipper::Instrumentation::EventSubscriber do
  let(:test_user) { build(:user) }

  context 'logs changes to toggle values' do
    it 'logs feature calls with result after operation for disable' do
      Flipper.disable(:this_is_only_a_test) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('this_is_only_a_test')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('boolean')
    end

    it 'logs feature calls with result after operation for disable_percentage_of_actors' do
      Flipper.disable_percentage_of_actors(:this_is_only_a_test) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('this_is_only_a_test')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('percentage_of_actors')
    end

    it 'logs feature calls with result after operation for disable_percentage_of_time' do
      Flipper.disable_percentage_of_time(:this_is_only_a_test) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('this_is_only_a_test')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('percentage_of_time')
    end

    it 'logs feature calls with result after operation for enable_percentage_of_actors' do
      Flipper.enable_percentage_of_actors :this_is_only_a_test, 10 # rubocop:disable Project/ForbidFlipperToggleInSpecs
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('this_is_only_a_test')
      expect(last_event.operation).to eq('enable')
      expect(last_event.gate_name).to eq('percentage_of_actors')
    end

    it 'logs feature calls with result after operation for enable_percentage_of_time' do
      Flipper.enable_percentage_of_time :this_is_only_a_test, 5 # rubocop:disable Project/ForbidFlipperToggleInSpecs
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('this_is_only_a_test')
      expect(last_event.operation).to eq('enable')
      expect(last_event.gate_name).to eq('percentage_of_time')
    end

    it 'logs feature calls with result after operation for enable_actor' do
      Flipper.enable_actor :this_is_only_a_test, test_user # rubocop:disable Project/ForbidFlipperToggleInSpecs
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('this_is_only_a_test')
      expect(last_event.operation).to eq('enable')
      expect(last_event.gate_name).to eq('actor')
    end

    it 'logs feature calls with result after operation for disable_actor' do
      Flipper.disable_actor :this_is_only_a_test, test_user # rubocop:disable Project/ForbidFlipperToggleInSpecs
      last_event = FeatureToggleEvent.last
      expect(last_event.feature_name).to eq('this_is_only_a_test')
      expect(last_event.operation).to eq('disable')
      expect(last_event.gate_name).to eq('actor')
    end
  end

  context 'does not log evaluation of toggle values' do
    it 'something' do
      expect do
        Flipper.enabled?(:this_is_only_a_test, @current_user)
      end.not_to change(FeatureToggleEvent, :count)
    end
  end
end
