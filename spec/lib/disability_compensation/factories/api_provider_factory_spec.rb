# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe ApiProviderFactory do
  let(:current_user) { build(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(current_user).add_headers(EVSS::AuthHeaders.new(current_user).to_h)
  end
  let(:icn) { current_user.icn.to_s }

  context 'rated_disabilities' do
    it 'provides an EVSS rated disabilities provider' do
      expect(provider(:evss).class).to equal(EvssRatedDisabilitiesProvider)
    end

    it 'provides a Lighthouse rated disabilities provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseRatedDisabilitiesProvider)
    end

    it 'provides rated disabilities provider based on Flipper' do
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND)
      provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:rated_disabilities],
        provider: nil,
        options: { icn:, auth_headers: },
        current_user: nil,
        feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND
      )
      expect(provider.class).to equal(LighthouseRatedDisabilitiesProvider)

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND)
      provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:rated_disabilities],
        provider: nil,
        options: { icn:, auth_headers: },
        current_user: nil,
        feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND
      )
      expect(provider.class).to equal(EvssRatedDisabilitiesProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:rated_disabilities],
          provider: :random,
          options: { icn:, auth_headers: },
          current_user: nil,
          feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND
        )
      end.to raise_error NotImplementedError
    end

    def provider(api_provider = nil, feature_toggle = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:rated_disabilities],
        provider: api_provider,
        options: { icn:, auth_headers: },
        current_user: nil,
        feature_toggle:
      )
    end
  end

  context 'intent_to_file' do
    it 'provides an EVSS intent to file provider' do
      expect(provider(:evss).class).to equal(EvssIntentToFileProvider)
    end

    it 'provides a Lighthouse intent to file provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseIntentToFileProvider)
    end

    it 'provides intent to file provider based on Flipper' do
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
      expect(provider.class).to equal(LighthouseIntentToFileProvider)

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
      expect(provider.class).to equal(EvssIntentToFileProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end

    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:intent_to_file],
        provider: api_provider,
        options: {},
        current_user:,
        feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE
      )
    end
  end

  context 'claims service' do
    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:claims],
        provider: api_provider,
        options: { icn: current_user.icn },
        current_user:,
        feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_CLAIMS_SERVICE
      )
    end

    it 'provides an EVSS claims service provider' do
      expect(provider(:evss).class).to equal(EvssClaimsServiceProvider)
    end

    it 'provides a Lighthouse claims service provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseClaimsServiceProvider)
    end

    it 'provides claims service provider based on Flipper' do
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_CLAIMS_SERVICE)
      expect(provider.class).to equal(LighthouseClaimsServiceProvider)

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_CLAIMS_SERVICE)
      expect(provider.class).to equal(EvssClaimsServiceProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end
  end

  context 'ppiu direct deposit' do
    it 'provides an evss ppiu provider' do
      expect(provider(:evss).class).to equal(EvssPPIUProvider)
    end

    it 'provides a Lighthouse ppiu direct deposit provider' do
      # TODO: Uncomment once Lighthouse provider is implemented in #59698
      # expect(provider(:lighthouse).class).to equal(LighthousePPIUProvider)

      # TODO: Remove once Lighthouse provider is implemented in #59698
      expect do
        provider(:lighthouse)
      end.to raise_error NotImplementedError
    end

    it 'provides ppiu direct deposit provider based on Flipper' do
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
      # TODO: Uncomment once Lighthouse provider is implemented in #59698
      # expect(provider.class).to equal(LighthousePPIUProvider)

      # TODO: Remove once Lighthouse provider is implemented in #59698
      expect do
        provider
      end.to raise_error NotImplementedError

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
      expect(provider.class).to equal(EvssPPIUProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end

    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:ppiu],
        provider: api_provider,
        options: {},
        current_user:,
        feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT
      )
    end
  end
end
