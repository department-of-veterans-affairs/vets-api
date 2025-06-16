# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeatureTogglesService do
  subject(:service) { described_class.new(current_user: user, cookie_id:) }

  let(:user) { build(:user) }
  let(:cookie_id) { 'test-cookie-id' }

  describe '#get_features' do
    let(:features_params) { %w[feature1 feature2] }

    before do
      allow(FLIPPER_FEATURE_CONFIG).to receive(:[]).with('features').and_return(
        'feature1' => { 'actor_type' => 'user' },
        'feature2' => { 'actor_type' => 'cookie' }
      )
      allow(Flipper).to receive(:enabled?).with('feature1', user).and_return(true)
      allow(Flipper).to receive(:enabled?).with('feature2', instance_of(Flipper::Actor)).and_return(false)
    end

    it 'returns the expected features with correct values' do
      result = service.get_features(features_params)
      expect(result).to eq([
                             { name: 'feature1', value: true },
                             { name: 'feature2', value: false }
                           ])
    end
  end

  describe '#get_all_features' do
    let(:features) do
      [
        { name: 'feature1', enabled: false, actor_type: 'user', gate_key: 'actors' },
        { name: 'feature2', enabled: true, actor_type: 'cookie', gate_key: 'boolean' }
      ]
    end

    before do
      allow(service).to receive(:fetch_features_with_gate_keys).and_return(features)
      allow(service).to receive(:add_feature_gate_values)
      allow(service).to receive(:format_features).with(features).and_return(
        [
          { name: 'feature1CamelCase', value: false },
          { name: 'feature1', value: false },
          { name: 'feature2CamelCase', value: true },
          { name: 'feature2', value: true }
        ]
      )
    end

    it 'calls the expected methods and returns formatted features' do
      result = service.get_all_features

      expect(service).to have_received(:fetch_features_with_gate_keys)
      expect(service).to have_received(:add_feature_gate_values).with(features)
      expect(service).to have_received(:format_features).with(features)

      expect(result).to eq([
                             { name: 'feature1CamelCase', value: false },
                             { name: 'feature1', value: false },
                             { name: 'feature2CamelCase', value: true },
                             { name: 'feature2', value: true }
                           ])
    end
  end

  describe 'private methods' do
    describe '#resolve_actor' do
      context 'when actor_type is for cookies' do
        let(:actor_type) { 'cookie' }

        before do
          # Instead of mocking the constant, stub the comparison
          allow(service).to receive(:resolve_actor).and_call_original
          stub_const('FLIPPER_ACTOR_STRING', 'cookie')
        end

        it 'returns a Flipper::Actor with the cookie_id' do
          result = service.send(:resolve_actor, actor_type)

          expect(result).to be_a(Flipper::Actor)
          expect(result.flipper_id).to eq(cookie_id)
        end
      end

      context 'when actor_type is for users' do
        let(:actor_type) { 'user' }

        before do
          # Instead of mocking the constant, stub the comparison
          allow(service).to receive(:resolve_actor).and_call_original
          stub_const('FLIPPER_ACTOR_STRING', 'cookie') # Different value than actor_type
        end

        it 'returns the user' do
          result = service.send(:resolve_actor, actor_type)

          expect(result).to eq(user)
        end
      end
    end
  end
end
