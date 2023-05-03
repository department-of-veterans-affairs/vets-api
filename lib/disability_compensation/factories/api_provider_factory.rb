# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/evss_rated_disabilities_provider'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'
require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'
require 'disability_compensation/providers/intent_to_file/evss_intent_to_file_provider'
require 'disability_compensation/providers/intent_to_file/lighthouse_intent_to_file_provider'
require 'disability_compensation/providers/intent_to_file/intent_to_file_provider'

class ApiProviderFactory
  API_PROVIDER = {
    evss: :evss,
    lighthouse: :lighthouse
  }.freeze

  FEATURE_TOGGLE_RATED_DISABILITIES = 'disability_compensation_lighthouse_rated_disabilities_provider'
  FEATURE_TOGGLE_INTENT_TO_FILE = 'disability_compensation_lighthouse_intent_to_file_provider'

  # @param [hash] options: options to provide auth_headers
  # @option options [hash] :auth_headers auth headers for the EVSS request
  # @option options [string] :icn Veteran's ICN
  def self.rated_disabilities_service_provider(options, api_provider = nil)
    api_provider ||= if Flipper.enabled?(FEATURE_TOGGLE_RATED_DISABILITIES)
                       API_PROVIDER[:lighthouse]
                     else
                       API_PROVIDER[:evss]
                     end

    case api_provider
    when API_PROVIDER[:evss]
      EvssRatedDisabilitiesProvider.new(options[:auth_headers])
    when API_PROVIDER[:lighthouse]
      LighthouseRatedDisabilitiesProvider.new(options[:icn])
    else
      raise NotImplementedError, 'No known Rated Disabilities Api Provider type provided'
    end
  end

  def self.intent_to_file_service_provider(current_user, api_provider = nil)
    api_provider ||= if Flipper.enabled?(FEATURE_TOGGLE_INTENT_TO_FILE)
                       API_PROVIDER[:lighthouse]
                     else
                       API_PROVIDER[:evss]
                     end

    case api_provider
    when API_PROVIDER[:evss]
      EvssIntentToFileProvider.new(current_user)
    when API_PROVIDER[:lighthouse]
      # TODO: Implement this
      raise NotImplementedError, 'Not implemented yet'
      # LighthouseIntentToFileProvider.new(current_user)
    else
      raise NotImplementedError, 'No known Rated Disabilities Api Provider type provided'
    end
  end
end
