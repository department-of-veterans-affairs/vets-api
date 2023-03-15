# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/evss_rated_disabilities_provider'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'
require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'

class ApiProviderFactory
  API_PROVIDER = {
    evss: :evss,
    lighthouse: :lighthouse
  }.freeze

  def self.rated_disabilities_service_provider(current_user, api_provider = :evss)
    case api_provider
    when :evss
      EvssRatedDisabilitiesProvider.new(current_user)
    when :lighthouse
      LighthouseRatedDisabilitiesProvider.new(current_user)
    else
      raise NotImplementedError, 'No known Rated Disabilities Api Provider type provided'
    end
  end
end
