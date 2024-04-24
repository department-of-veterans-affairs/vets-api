# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

require 'claims_api/claim_logger'
require 'claims_api/error/soap_error_handler'
require 'bgs_service/bgs_helpers'
require 'bgs_service/miscellaneous_bgs_operations'

module ClaimsApi
  class LocalBGS
    include ClaimsApi::MiscellaneousBGSOperations
    include ClaimsApi::BGSHelpers

    class << self
      def breakers_service
        BGSClient.breakers_service
      end
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
      service =
        BGSClient::ServiceAction::Definition::Service.new(
          path: endpoint,
          # Namespaces are only actually relevant when performing a service
          # action request. We could easily slightly tweak the API to reflect
          # that, but it's probably not horrible leaving it slightly funky here
          # for vague aesthetic reasons.
          namespaces: nil
        )

      BGSClient.healthcheck(
        service
      )
    end

    def make_request( # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      endpoint:, action:, body:, key: nil,
      namespaces: {}, transform_response: true
    )
      service =
        BGSClient::ServiceAction::Definition::Service.new(
          path: endpoint,
          namespaces:
        )

      action =
        BGSClient::ServiceAction::Definition::Action.new(
          name: action
        )

      definition =
        BGSClient::ServiceAction::Definition.new(
          service:,
          action:
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

      SoapErrorHandler.handle_errors!(
        result.value
      )

      {}
    end
  end
end
