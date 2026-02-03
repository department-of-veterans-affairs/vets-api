# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'sm/client'
require 'mobile/v0/messaging/client_session'
require 'mobile/v0/messaging/configuration'

module Mobile
  module V0
    module Messaging
      ##
      # Class responsible for SM API interface operations
      # Overrides configuration class member to use mobile-specific token
      # Overrides client_session class member to use mobile-specific
      #  session cache
      #
      class Client < SM::Client
        configuration Mobile::V0::Messaging::Configuration
        client_session Mobile::V0::Messaging::ClientSession

        ##
        # Override parent get_folder_messages to add schema contract validation
        #
        # @param user_uuid [String] user's uuid
        # @param folder_id [String] id of the folder
        # @param use_cache [Boolean] whether to use cached response
        # @return [Vets::Collection] collection of Message objects
        #
        def get_folder_messages(user_uuid, folder_id, use_cache)
          response = super
          validate_response_schema(user_uuid, response, 'messages_index')
          response
        end

        ##
        # Override parent get_message to add schema contract validation
        #
        # @param id [Integer] message id
        # @return [Message] the message object
        #
        def get_message(id)
          response = super
          validate_response_schema(session.user_uuid, response, 'message_show')
          response
        end

        ##
        # Override parent get_all_triage_teams to add schema contract validation
        #
        # @param user_uuid [String] user's uuid
        # @param use_cache [Boolean] whether to use cached response
        # @return [Vets::Collection] collection of AllTriageTeams objects
        #
        def get_all_triage_teams(user_uuid, use_cache)
          response = super
          validate_response_schema(user_uuid, response, 'triage_teams')
          response
        end

        private

        ##
        # Validates response data against schema contract
        # Looks up user by UUID and initiates async schema validation
        #
        # @param user_uuid [String] user's UUID to look up
        # @param response [Object] the response object from SM API
        # @param contract_name [String] name of the schema contract
        #
        def validate_response_schema(user_uuid, response, contract_name)
          return if response.blank?

          user = ::User.find(user_uuid)

          body = response_to_hash(response)
          return if body.blank?

          SchemaContract::ValidationInitiator.call_with_body(user:, body:, contract_name:)
        rescue ActiveRecord::RecordNotFound
          # Missing user likely indicates a data consistency issue; log distinctly and skip validation
          Rails.logger.warn('Mobile messaging schema validation skipped - user not found',
                            { contract_name:, user_uuid: })
        rescue => e
          # Log but don't block - schema validation should never break user requests
          Rails.logger.error('Mobile messaging schema validation error',
                             { contract_name:, user_uuid:, error: e.message })
        end

        ##
        # Converts response object to hash for schema validation
        #
        # @param response [Object] Vets::Collection or model object
        # @return [Hash] hash representation of the response
        #
        def response_to_hash(response)
          if response.respond_to?(:data)
            # Vets::Collection - convert to array of hashes
            { data: response.data.map { |item| item.attributes.to_h } }
          elsif response.respond_to?(:attributes)
            # Single model object
            response.attributes.to_h
          else
            response.to_h
          end
        end
      end
    end
  end
end
