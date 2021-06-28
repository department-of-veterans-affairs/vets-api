# frozen_string_literal: true

require 'rails_helper'

describe FeatureToggles::Bundle do
  subject { described_class }

  let(:all_hash) do
    {
      'foo_bar_feature' => { 'actor_type' => 'user' },
      'my_new_feature' => { 'actor_type' => 'cookie_id' },
      'cool_feature' => { 'actor_type' => 'user' }
    }
  end

  describe 'object initialization' do
    let(:bundle) { described_class.build({}) }

    it 'responds to attributes' do
      expect(bundle.respond_to?(:cookie_id)).to eq(true)
      expect(bundle.respond_to?(:actor)).to eq(true)
      expect(bundle.respond_to?(:features)).to eq(true)
      expect(bundle.respond_to?(:current_user)).to eq(true)
    end
  end

  describe '.build' do
    it 'returns an instance of the described class' do
      expect(described_class.build({})).to be_an_instance_of(described_class)
    end
  end

  describe '#fetch' do
    before do
      allow_any_instance_of(described_class).to receive(:features).and_return(params_features)
      allow_any_instance_of(described_class).to receive(:features_hash).and_return(all_hash)
    end

    context 'with features' do
      let(:features_response) do
        [
          { name: 'foo_bar_feature', value: true },
          { name: 'cool_feature', value: true }
        ]
      end
      let(:params_features) { %w[foo_bar_feature cool_feature] }

      it 'builds the feature hash for a subset of features' do
        allow_any_instance_of(described_class).to receive(:enabled?).and_return(true)

        expect(described_class.build({}).fetch).to eq(features_response)
      end
    end

    context 'without features' do
      let(:params_features) { [] }

      it 'returns nil' do
        expect(described_class.build({}).fetch).to eq(nil)
      end
    end
  end

  describe '#redis_key' do
    before do
      allow_any_instance_of(described_class).to receive(:features).and_return(params_features)
    end

    context 'when features' do
      let(:params_features) { %w[foo_bar_feature cool_feature] }

      it 'returns a shorted key' do
        expect(described_class.build({}).redis_key).to eq('flippers/281b8123f3f8af1826b8ed07c3e184c66a658554')
      end
    end

    context 'when no features' do
      let(:params_features) { [] }

      it 'returns nil' do
        expect(described_class.build({}).redis_key).to eq(nil)
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
