# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

require 'bgs_service/local_bgs_refactored/error_handler'
require 'bgs_service/local_bgs_refactored/miscellaneous'
require 'claims_api/bgs_client'
require 'claims_api/claim_logger'

module ClaimsApi
  # @deprecated Use {BGSClient.perform_request} instead. There ought to be a
  #   clear separation between the single method that performs the transport to
  #   BGS and any business logic that invokes said transport. By housing that
  #   single method as an instance method of this class, we encouraged
  #   business logic modules to inherit this class and then inevitably start to
  #   conflate business logic back into the transport layer here. There was a
  #   particularly easy temptation to put business object state validation as
  #   well as the dumping and loading of business object state into this layer,
  #   but that should live in the business logic layer and not here.
  class LocalBGSRefactored
    include Miscellaneous

    class << self
      delegate :breakers_service, to: BGSClient
    end

    attr_reader :external_id

    def initialize(
      external_uid: Settings.bgs.external_uid,
      external_key: Settings.bgs.external_key
    )
      @external_id =
        BGSClient::ServiceAction::ExternalId.new(
          external_uid:,
          external_key:
        )
    end

    def healthcheck(endpoint)
      definition =
        BGSClient::ServiceAction::Definition.new(
          service_path: endpoint,
          service_namespaces: nil,
          action_name: nil
        )

      BGSClient.healthcheck(
        definition
      )
    end

    def make_request( # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      endpoint:, action:, body:, key: nil,
      namespaces: {}, transform_response: true
    )
      definition =
        BGSClient::ServiceAction::Definition.new(
          service_path: endpoint,
          service_namespaces: namespaces,
          action_name: action
        )

      request =
        BGSClient::ServiceAction.const_get(:Request).new(
          definition:,
          external_id:
        )

      result = request.perform(body)

      if result.success?
        value = result.value.to_h
        value = value[key].to_h if key.present?

        if transform_response
          request.send(:log_duration, 'transformed_response') do
            value.deep_transform_keys! do |key|
              key.underscore.to_sym
            end
          end
        end

        return value
      end

      ErrorHandler.handle_errors!(
        result.value
      )

      {}
    end
  end
end
