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
      # TODO: This will change once we implement the Lighthouse Rated Disabilities Provider
      expect do
        ApiProviderFactory.rated_disabilities_service_provider(current_user, :lighthouse)
      end.to raise_error NotImplementedError
    end

    it 'provides rated disabilities provider' do
      expect do
        ApiProviderFactory.rated_disabilities_service_provider(current_user, nil)
      end.to raise_error NotImplementedError
    end
  end
end
