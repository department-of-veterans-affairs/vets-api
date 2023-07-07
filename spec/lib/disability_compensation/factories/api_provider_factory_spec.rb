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
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES)
      provider = ApiProviderFactory.rated_disabilities_service_provider({ auth_headers:, icn: })
      expect(provider.class).to equal(LighthouseRatedDisabilitiesProvider)

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES)
      provider = ApiProviderFactory.rated_disabilities_service_provider({ auth_headers:, icn: })
      expect(provider.class).to equal(EvssRatedDisabilitiesProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        ApiProviderFactory.rated_disabilities_service_provider({ auth_headers:, icn: }, :random)
      end.to raise_error NotImplementedError
    end

    def provider(api_provider = nil)
      ApiProviderFactory.rated_disabilities_service_provider(
        { auth_headers:, icn: },
        api_provider
      )
    end
  end

  context 'intent_to_file' do
    it 'provides an EVSS intent to file provider' do
      provider = ApiProviderFactory.intent_to_file_service_provider(current_user, :evss)
      expect(provider.class).to equal(EvssIntentToFileProvider)
    end

    it 'provides a Lighthouse intent to file provider' do
      provider = ApiProviderFactory.intent_to_file_service_provider(current_user, :lighthouse)
      expect(provider.class).to equal(LighthouseIntentToFileProvider)
    end

    it 'provides intent to file provider based on Flipper' do
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
      provider = ApiProviderFactory.intent_to_file_service_provider(current_user)
      expect(provider.class).to equal(LighthouseIntentToFileProvider)

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
      provider = ApiProviderFactory.intent_to_file_service_provider(current_user)
      expect(provider.class).to equal(EvssIntentToFileProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        ApiProviderFactory.intent_to_file_service_provider(current_user, :random)
      end.to raise_error NotImplementedError
    end
  end

  context 'ppiu direct deposit' do
    it 'provides an evss ppiu provider' do
      provider = ApiProviderFactory.ppiu_service_provider(current_user, :evss)
      expect(provider.class).to equal(EvssPPIUProvider)
    end

    it 'provides a Lighthouse ppiu direct deposit provider' do
      # TODO: Uncomment once Lighthouse provider is implemented in #59698
      # provider = ApiProviderFactory.ppiu_service_provider(current_user, :lighthouse)
      # expect(provider.class).to equal(LighthousePPIUProvider)

      # TODO: Remove once Lighthouse provider is implemented in #59698
      expect do
        ApiProviderFactory.ppiu_service_provider(current_user, :lighthouse)
      end.to raise_error NotImplementedError
    end

    it 'provides ppiu direct deposit provider based on Flipper' do
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
      # TODO: Uncomment once Lighthouse provider is implemented in #59698
      # provider = ApiProviderFactory.ppiu_service_provider(current_user)
      # expect(provider.class).to equal(LighthousePPIUProvider)

      # TODO: Remove once Lighthouse provider is implemented in #59698
      expect do
        ApiProviderFactory.ppiu_service_provider(current_user)
      end.to raise_error NotImplementedError

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
      provider = ApiProviderFactory.ppiu_service_provider(current_user)
      expect(provider.class).to equal(EvssPPIUProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        ApiProviderFactory.ppiu_service_provider(current_user, :random)
      end.to raise_error NotImplementedError
    end
  end
end
