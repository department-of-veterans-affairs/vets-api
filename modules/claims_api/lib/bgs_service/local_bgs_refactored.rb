# frozen_string_literal: true

require 'bgs_service/local_bgs_refactored/error_handler'
require 'bgs_service/local_bgs_refactored/find_service_definition'
require 'bgs_service/local_bgs_refactored/miscellaneous'

module ClaimsApi
  ##
  # @deprecated Use {BGSClient.perform_request} instead. There ought to be a
  #   clear separation between the single method that performs the transport to
  #   BGS and any business logic that invokes said transport. By housing that
  #   single method as an instance method of this class, we encouraged
  #   business logic modules to inherit this class and then inevitably start to
  #   conflate business logic back into the transport layer here. There was a
  #   particularly easy temptation to put business object state validation as
  #   well as the dumping and loading of business object state into this layer,
  #   but that should live in the business logic layer and not here. Commentary
  #   about deprecation reasons is enumerated inline with the implementation
  #   below.
  ##
  # @deprecated Doesn't conform to Rails autoloading conventions, so we don't
  #   get it autoloaded across the project.
  #
  class LocalBGSRefactored
    ##
    # @deprecated This bag of miscellaneous behavior is meant for callers of
    #   this, rather than being centralized here.
    include Miscellaneous

    ##
    # @deprecated Not all (or perhaps any?) of these correspond to genuine bad
    #   gateway `502` errors.
    #
    BAD_GATEWAY_EXCEPTIONS = [
      BGSClient::Error::ConnectionFailed,
      BGSClient::Error::SSLError,
      BGSClient::Error::TimeoutError
    ].freeze

    class << self
      delegate :breakers_service, to: BGSClient
    end

    ##
    # @deprecated Can use default named arguments. Not really a deprecation
    #   reason.
    #
    def initialize(external_uid:, external_key:)
      external_uid ||= Settings.bgs.external_uid
      external_key ||= Settings.bgs.external_key

      @external_id =
        BGSClient::ExternalId.new(
          external_uid:,
          external_key:
        )
    end

    ##
    # @deprecated Prefer doing just transport against bundled BGS service action
    #   definitions rather than wrapping them at higher abstraction layers.
    #
    def make_request(
      endpoint:, action:, body:, key: nil
    )
      service = FindServiceDefinition.perform(endpoint)
      action = BGSClient::Definitions::Action.new(service:, name: action)

      request =
        BGSClient.const_get(:Request).new(
          external_id: @external_id,
          action:
        )

      ##
      # @deprecated Callers should be hydrating domain entities anyway, so
      #   centralizing `key` configuration here was unnecessary.
      #
      result = request.perform(body)
      result = result[key].to_h if key.present?

      request.send(:log_duration, 'transformed_response') do
        ##
        # @deprecated Callers should be hydrating domain entities anyway, so
        #   this transformation pass is wasteful.
        #
        result.deep_transform_keys! do |k|
          k.underscore.to_sym
        end
      end

      result
    rescue *BAD_GATEWAY_EXCEPTIONS
      ##
      # @deprecated We were determining our external interface extremely low in
      #   the stack by raising one of our externally facing application errors
      #   here.
      #
      raise ::Common::Exceptions::BadGateway
    rescue BGSClient::Error::BGSFault => e
      ##
      # @deprecated This error handler handles the logic for multiple different
      #   callers rather than those callers handling their own logic.
      #
      ErrorHandler.handle_errors!(e)
      {}
    end

    ##
    # @deprecated Prefer doing just transport against bundled BGS service action
    #   definitions rather than wrapping them at higher abstraction layers.
    #
    def healthcheck(endpoint)
      service = FindServiceDefinition.perform(endpoint)
      BGSClient.healthcheck(service)
    end
  end
end
