# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/evss_rated_disabilities_provider'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'
require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'
require 'disability_compensation/providers/intent_to_file/evss_intent_to_file_provider'
require 'disability_compensation/providers/intent_to_file/lighthouse_intent_to_file_provider'
require 'disability_compensation/providers/intent_to_file/intent_to_file_provider'
require 'disability_compensation/providers/ppiu_direct_deposit/ppiu_provider'
require 'disability_compensation/providers/ppiu_direct_deposit/evss_ppiu_provider'
require 'disability_compensation/providers/ppiu_direct_deposit/lighthouse_ppiu_provider'
require 'logging/third_party_transaction'

class ApiProviderFactory
  extend Logging::ThirdPartyTransaction::MethodWrapper
  class UndefinedFactoryTypeError < StandardError; end

  API_PROVIDER = {
    evss: :evss,
    lighthouse: :lighthouse
  }.freeze

  FACTORIES = {
    rated_disabilities: :rated_disabilities,
    intent_to_file: :intent_to_file,
    ppiu: :ppiu
  }.freeze

  # Splitting the rated disabilities functionality into two use cases:
  # 1. foreground tasks (i.e. web requests)
  # 2. the background jobs (i.e. submit526 job)
  FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND =
    'disability_compensation_lighthouse_rated_disabilities_provider_foreground'
  FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND =
    'disability_compensation_lighthouse_rated_disabilities_provider_background'
  FEATURE_TOGGLE_INTENT_TO_FILE = 'disability_compensation_lighthouse_intent_to_file_provider'

  # PPIU calls out to Direct Deposit APIs in Lighthouse
  FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT = 'disability_compensation_lighthouse_ppiu_direct_deposit_provider'

  wrap_with_logging(
    :rated_disabilities_service_provider,
    :intent_to_file_service_provider,
    :ppiu_service_provider,
    additional_class_logs: {
      action: 'disability compensation factory choosing API Provider'
    },
    additional_instance_logs: {
      provider: %i[api_provider]
    }
  )

  def self.call(**)
    new(**).call
  end

  def initialize(type:, current_user:, provider: nil, options: {}, feature_toggle: nil)
    @type = type
    @api_provider = provider
    @options = options
    # current user is necessary for the Flipper toggle to check against
    @current_user = current_user
    # for now, rated disabilities is the only special case that needs the feature toggle name sent in
    @feature_toggle = feature_toggle
  end

  def call
    case @type
    when FACTORIES[:rated_disabilities]
      rated_disabilities_service_provider
    when FACTORIES[:intent_to_file]
      intent_to_file_service_provider
    when FACTORIES[:ppiu]
      ppiu_service_provider
    else
      raise UndefinedFactoryTypeError
    end
  end

  private

  def rated_disabilities_service_provider
    case api_provider
    when API_PROVIDER[:evss]
      EvssRatedDisabilitiesProvider.new(@options[:auth_headers])
    when API_PROVIDER[:lighthouse]
      LighthouseRatedDisabilitiesProvider.new(@options[:icn])
    else
      raise NotImplementedError, 'No known Rated Disabilities Api Provider type provided'
    end
  end

  def intent_to_file_service_provider
    @feature_toggle = FEATURE_TOGGLE_INTENT_TO_FILE
    case api_provider
    when API_PROVIDER[:evss]
      EvssIntentToFileProvider.new(@current_user, nil)
    when API_PROVIDER[:lighthouse]
      LighthouseIntentToFileProvider.new(@current_user)
    else
      raise NotImplementedError, 'No known Intent to File Api Provider type provided'
    end
  end

  def ppiu_service_provider
    @feature_toggle = FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT
    case api_provider
    when API_PROVIDER[:evss]
      EvssPPIUProvider.new(@current_user)
    when API_PROVIDER[:lighthouse]
      # TODO: Implement in #59698 - Lighthouse provider
      # LighthousePPIUProvider.new(current_user)
      raise NotImplementedError, 'Lighthouse PPIU Provider not implemented yet'
    else
      raise NotImplementedError, 'No known PPIU Api Provider type provided'
    end
  end

  def api_provider
    @api_provider ||= if Flipper.enabled?(@feature_toggle, @current_user)
                        API_PROVIDER[:lighthouse]
                      else
                        API_PROVIDER[:evss]
                      end
  end
end
