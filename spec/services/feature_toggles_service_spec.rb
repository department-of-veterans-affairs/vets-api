# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeatureTogglesService do
  subject(:service) { described_class.new(current_user: user, cookie_id:) }

  let(:user) { build(:user) }
  let(:cookie_id) { 'test-cookie-id' }

  describe '#get_features' do
    let(:features_params) { %w[feature_one feature_two] }

    before do
      allow(FLIPPER_FEATURE_CONFIG).to receive(:[]).with('features').and_return(
        'feature_one' => { 'actor_type' => 'user' },
        'feature_two' => { 'actor_type' => 'cookie' }
      )
      allow(Flipper).to receive(:enabled?).with('feature_one', user).and_return(true)
      allow(Flipper).to receive(:enabled?).with('feature_two', instance_of(Flipper::Actor)).and_return(false)
    end

    it 'returns the expected features with correct values' do
      result = service.get_features(features_params)
      expect(result).to eq([
                             { name: 'feature_one', value: true },
                             { name: 'feature_two', value: false }
                           ])
    end
  end

  describe '#get_all_features' do
    let(:expected_result) do
      [
        { name: 'featureOne', value: false },
        { name: 'feature_one', value: false },
        { name: 'featureTwo', value: true },
        { name: 'feature_two', value: true }
      ]
    end

    let(:features) do
      [
        { name: 'feature_one', enabled: false, actor_type: 'user', gate_key: 'actors' },
        { name: 'feature_two', enabled: true, actor_type: 'cookie', gate_key: 'boolean' }
      ]
    end

    before do
      allow_any_instance_of(FeatureTogglesService).to receive(:feature_gates).and_return(
        [
          {
            'feature_name' => 'feature_one',
            'gate_key' => 'actors',
            'value' => nil
          },
          {
            'feature_name' => 'feature_two',
            'gate_key' => 'boolean',
            'value' => 'true'
          }
        ]
      )

      allow(FLIPPER_FEATURE_CONFIG).to receive(:[]).with('features').and_return(
        'feature_one' => { 'actor_type' => 'user' },
        'feature_two' => { 'actor_type' => 'cookie' }
      )

      allow(Flipper).to receive(:enabled?).with('feature_one', user).and_return(false)
      allow(Flipper).to receive(:enabled?).with('feature_two', instance_of(Flipper::Actor)).and_return(true)
    end

    it 'returns formatted features' do
      result = service.get_all_features
      expect(result).to eq(expected_result)
    end
  end

  describe 'private methods' do
    describe '#resolve_actor' do
      context 'when actor_type is for cookies' do
        let(:actor_type) { 'cookie' }
        let(:instance) { described_class.new(current_user: user, cookie_id:) }

        before do
          stub_const('FLIPPER_ACTOR_STRING', 'cookie')
        end

        it 'returns a Flipper::Actor with the cookie_id' do
          result = instance.send(:resolve_actor, actor_type)

          expect(result).to be_a(Flipper::Actor)
          expect(result.flipper_id).to eq(cookie_id)
        end
      end

      context 'when actor_type is for users' do
        let(:actor_type) { 'user' }
        let(:instance) { described_class.new(current_user: user, cookie_id:) }

        before do
          stub_const('FLIPPER_ACTOR_STRING', 'cookie') # Different value than actor_type
        end

        it 'returns the user' do
          result = instance.send(:resolve_actor, actor_type)

          expect(result).to eq(user)
        end
      end
    end
  end
end
