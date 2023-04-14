# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe ApiProviderFactory do
  let(:current_user) { build(:user, :loa3) }

  context 'rated_disabilities' do
    it 'provides an EVSS rated disabilities provider' do
      provider = ApiProviderFactory.rated_disabilities_service_provider(current_user, :evss)
      expect(provider.class).to equal(EvssRatedDisabilitiesProvider)
    end

    it 'provides a Lighthouse rated disabilities provider' do
      provider = ApiProviderFactory.rated_disabilities_service_provider(current_user, :lighthouse)
      expect(provider.class).to equal(LighthouseRatedDisabilitiesProvider)
    end

    it 'provides rated disabilities provider based on Flipper' do
      Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES)
      provider = ApiProviderFactory.rated_disabilities_service_provider(current_user)
      expect(provider.class).to equal(LighthouseRatedDisabilitiesProvider)

      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES)
      provider = ApiProviderFactory.rated_disabilities_service_provider(current_user)
      expect(provider.class).to equal(EvssRatedDisabilitiesProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        ApiProviderFactory.rated_disabilities_service_provider(current_user, :random)
      end.to raise_error NotImplementedError
    end
  end
end
