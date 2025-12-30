# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/providers/provider_registry'
require 'benefits_claims/providers/benefits_claims/benefits_claims_provider'

RSpec.describe BenefitsClaims::Providers::ProviderRegistry do
  let(:mock_provider_class) do
    Class.new do
      include BenefitsClaims::Providers::BenefitsClaimsProvider
    end
  end

  let(:invalid_provider_class) do
    Class.new
  end

  let(:user) { build(:user, :loa3) }

  before do
    described_class.clear!
  end

  after do
    described_class.clear!
  end

  describe '.register' do
    it 'registers a provider with default options' do
      described_class.register(:test_provider, mock_provider_class)

      # Provider should not be enabled by default (enabled_by_default: false is default)
      expect(described_class.enabled?(:test_provider)).to be false
    end

    it 'registers a provider with feature flag' do
      described_class.register(
        :test_provider,
        mock_provider_class,
        feature_flag: 'test_flag',
        enabled_by_default: false
      )

      # Should check feature flag when available
      expect(described_class.enabled?(:test_provider)).to be false
    end

    it 'registers multiple providers' do
      described_class.register(:provider1, mock_provider_class, enabled_by_default: true)
      described_class.register(:provider2, mock_provider_class, enabled_by_default: false)

      expect(described_class.enabled?(:provider1)).to be true
      expect(described_class.enabled?(:provider2)).to be false
    end

    it 'freezes the config hash to prevent mutation' do
      described_class.register(:test_provider, mock_provider_class, enabled_by_default: true)
      config = described_class.get(:test_provider)

      expect(config).to be_frozen
      expect { config[:enabled_by_default] = false }.to raise_error(FrozenError)
    end

    context 'provider validation' do
      it 'accepts a provider class that includes BenefitsClaimsProvider' do
        expect do
          described_class.register(:valid_provider, mock_provider_class, enabled_by_default: true)
        end.not_to raise_error
      end

      it 'rejects a provider class that does not include BenefitsClaimsProvider' do
        expect do
          described_class.register(:invalid_provider, invalid_provider_class, enabled_by_default: true)
        end.to raise_error(ArgumentError, /must include BenefitsClaimsProvider module/)
      end

      it 'provides a helpful error message with the class name' do
        expect do
          described_class.register(:invalid_provider, invalid_provider_class, enabled_by_default: true)
        end.to raise_error(ArgumentError, /#{invalid_provider_class}/)
      end
    end
  end

  describe '.enabled?' do
    context 'with enabled_by_default true' do
      before do
        described_class.register(:test_provider, mock_provider_class, enabled_by_default: true)
      end

      it 'returns true by default' do
        expect(described_class.enabled?(:test_provider)).to be true
      end
    end

    context 'with enabled_by_default false' do
      before do
        described_class.register(:test_provider, mock_provider_class, enabled_by_default: false)
      end

      it 'returns false by default' do
        expect(described_class.enabled?(:test_provider)).to be false
      end
    end

    context 'with feature flag' do
      before do
        described_class.register(
          :test_provider,
          mock_provider_class,
          feature_flag: 'test_feature',
          enabled_by_default: false
        )
      end

      it 'checks feature flag when Flipper is defined' do
        skip 'Flipper not defined' unless defined?(Flipper)

        allow(Flipper).to receive(:enabled?).with('test_feature', user).and_return(true)
        expect(described_class.enabled?(:test_provider, user)).to be true
      end

      it 'checks feature flag and returns false when disabled' do
        skip 'Flipper not defined' unless defined?(Flipper)

        allow(Flipper).to receive(:enabled?).with('test_feature', user).and_return(false)
        expect(described_class.enabled?(:test_provider, user)).to be false
      end
    end

    context 'with unregistered provider' do
      it 'returns false' do
        expect(described_class.enabled?(:nonexistent)).to be false
      end
    end
  end

  describe '.enabled_provider_classes' do
    let(:provider_class_two) do
      Class.new { include BenefitsClaims::Providers::BenefitsClaimsProvider }
    end

    let(:provider_class_three) do
      Class.new { include BenefitsClaims::Providers::BenefitsClaimsProvider }
    end

    before do
      described_class.register(:provider1, mock_provider_class, enabled_by_default: true)
      described_class.register(:provider2, provider_class_two, enabled_by_default: false)
      described_class.register(:provider3, provider_class_three, enabled_by_default: true)
    end

    it 'returns only enabled provider classes' do
      enabled = described_class.enabled_provider_classes
      expect(enabled).to contain_exactly(mock_provider_class, provider_class_three)
    end

    it 'returns empty array when no providers are enabled' do
      described_class.clear!
      described_class.register(:provider1, mock_provider_class, enabled_by_default: false)

      expect(described_class.enabled_provider_classes).to eq([])
    end

    context 'with feature flags' do
      before do
        described_class.clear!
        described_class.register(
          :lighthouse,
          mock_provider_class,
          feature_flag: 'test_feature',
          enabled_by_default: false
        )
      end

      it 'includes provider when feature flag is enabled' do
        skip 'Flipper not defined' unless defined?(Flipper)

        allow(Flipper).to receive(:enabled?).with('test_feature', user).and_return(true)
        expect(described_class.enabled_provider_classes(user)).to include(mock_provider_class)
      end

      it 'excludes provider when feature flag is disabled' do
        skip 'Flipper not defined' unless defined?(Flipper)

        allow(Flipper).to receive(:enabled?).with('test_feature', user).and_return(false)
        expect(described_class.enabled_provider_classes(user)).to be_empty
      end
    end
  end

  describe '.get' do
    before do
      described_class.register(
        :test_provider,
        mock_provider_class,
        feature_flag: 'test_flag',
        enabled_by_default: true
      )
    end

    it 'returns the configuration for a registered provider' do
      config = described_class.get(:test_provider)

      expect(config).to be_a(Hash)
      expect(config[:class]).to eq(mock_provider_class)
      expect(config[:feature_flag]).to eq('test_flag')
      expect(config[:enabled_by_default]).to be true
    end

    it 'returns nil for an unregistered provider' do
      expect(described_class.get(:nonexistent)).to be_nil
    end

    it 'returns a frozen config hash' do
      config = described_class.get(:test_provider)
      expect(config).to be_frozen
    end
  end

  describe '.clear!' do
    it 'removes all registered providers' do
      described_class.register(:test_provider, mock_provider_class, enabled_by_default: true)
      expect(described_class.enabled_provider_classes).not_to be_empty

      described_class.clear!
      expect(described_class.enabled_provider_classes).to be_empty
    end

    it 'raises error in production environment' do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect { described_class.clear! }.to raise_error('ProviderRegistry.clear! cannot be called in production')
    end

    it 'works in non-production environments' do
      allow(Rails.env).to receive(:production?).and_return(false)

      described_class.register(:test_provider, mock_provider_class, enabled_by_default: true)
      expect { described_class.clear! }.not_to raise_error
      expect(described_class.enabled_provider_classes).to be_empty
    end
  end
end
