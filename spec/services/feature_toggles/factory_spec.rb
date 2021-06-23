# frozen_string_literal: true

require 'rails_helper'

describe FeatureToggles::Factory do
  subject { described_class }

  let(:all_hash) do
    {
      'foo_bar_feature' => { 'actor_type' => 'user' },
      'my_new_feature' => { 'actor_type' => 'cookie_id' }
    }
  end

  describe 'object initialization' do
    let(:factory) { described_class.build({}) }

    it 'responds to attributes' do
      expect(factory.respond_to?(:cookie_id)).to eq(true)
      expect(factory.respond_to?(:actor)).to eq(true)
      expect(factory.respond_to?(:features)).to eq(true)
      expect(factory.respond_to?(:current_user)).to eq(true)
    end
  end

  describe '.build' do
    it 'returns an instance of the described class' do
      expect(described_class.build({})).to be_an_instance_of(described_class)
    end
  end

  describe '#list' do
    let(:all_features) { [1, 2, 3, 4, 5] }
    let(:subset_features) { [4, 5] }

    before do
      allow_any_instance_of(described_class).to receive(:all).and_return(all_features)
      allow_any_instance_of(described_class).to receive(:subset).and_return(subset_features)
    end

    context 'when no features present in params' do
      it 'returns all features' do
        allow_any_instance_of(described_class).to receive(:features).and_return([])

        expect(described_class.build({}).list).to eq(all_features)
      end
    end

    context 'when features present in params' do
      it 'returns subset of features' do
        allow_any_instance_of(described_class).to receive(:features).and_return([4, 5])

        expect(described_class.build({}).list).to eq(subset_features)
      end
    end
  end

  describe '#all' do
    let(:features_response) do
      [
        { name: 'fooBarFeature', value: true },
        { name: 'foo_bar_feature', value: true },
        { name: 'myNewFeature', value: true },
        { name: 'my_new_feature', value: true }
      ]
    end

    before do
      allow_any_instance_of(described_class).to receive(:features_hash).and_return(all_hash)
      allow_any_instance_of(described_class).to receive(:enabled?).and_return(true)
    end

    it 'builds the feature hash for all available features' do
      expect(described_class.build({}).all).to eq(features_response)
    end
  end

  describe '#subset' do
    let(:features_response) do
      [
        { name: 'fooBarFeature', value: true },
        { name: 'foo_bar_feature', value: true }
      ]
    end

    before do
      allow_any_instance_of(described_class).to receive(:features).and_return(params_features)
      allow_any_instance_of(described_class).to receive(:features_hash).and_return(all_hash)
      allow_any_instance_of(described_class).to receive(:enabled?).and_return(true)
    end

    context 'when features param is camel cased' do
      let(:params_features) { ['fooBarFeature'] }

      it 'builds the feature hash for a subset of features' do
        expect(described_class.build({}).subset).to eq(features_response)
      end
    end

    context 'when features param is snake cased' do
      let(:params_features) { ['foo_bar_feature'] }

      it 'builds the feature hash for a subset of features' do
        expect(described_class.build({}).subset).to eq(features_response)
      end
    end
  end

  describe '#enabled?' do
    context 'when feature is enabled' do
      it 'returns true' do
        allow(Flipper).to receive(:enabled?).and_return(true)

        expect(described_class.build({}).enabled?('foo_bar', 'user')).to eq(true)
      end
    end

    context 'when feature is disabled' do
      it 'returns true' do
        allow(Flipper).to receive(:enabled?).and_return(false)

        expect(described_class.build({}).enabled?('foo_bar', 'user')).to eq(false)
      end
    end
  end

  describe '#body' do
    it 'returns the proper hash structure' do
      expect(described_class.build({}).body('foo_bar', true)).to eq({ name: 'foo_bar', value: true })
    end
  end

  describe '#actor_type' do
    context 'when cookie_id' do
      it 'returns an instance of Flipper::Actor' do
        expect(described_class.build({ cookie_id: '123abc' }).actor_type('cookie_id'))
          .to be_an_instance_of(Flipper::Actor)
      end
    end

    context 'when user' do
      it 'returns an instance of Flipper::Actor' do
        expect(described_class.build({ user: User.new }).actor_type('user'))
          .to be_an_instance_of(User)
      end
    end

    context 'when nil' do
      it 'returns an instance of Flipper::Actor' do
        expect(described_class.build({}).actor_type(nil)).to be_nil
      end
    end
  end

  describe '#features_hash' do
    it 'is a Hash' do
      expect(described_class.build({}).features_hash).to be_a(Hash)
    end

    it 'is not empty' do
      expect(described_class.build({}).features_hash.size.zero?).to be(false)
    end
  end
end
