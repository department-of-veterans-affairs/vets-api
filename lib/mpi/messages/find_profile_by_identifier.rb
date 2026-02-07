# frozen_string_literal: true

require_relative 'request_helper'
require_relative 'request_builder'
require 'mpi/constants'

module MPI
  module Messages
    class FindProfileByIdentifier
      attr_reader :identifier, :identifier_type, :search_type, :view_type

      def initialize(identifier:, identifier_type:, search_type: Constants::CORRELATION_WITH_RELATIONSHIP_DATA,
                     view_type: Constants::PRIMARY_VIEW)
        @identifier = identifier
        @identifier_type = identifier_type
        @search_type = search_type
        @view_type = view_type
      end

      def perform
        validate_types
        Messages::RequestBuilder.new(extension: Constants::FIND_PROFILE, body: build_body).perform
      rescue => e
        Rails.logger.error "[FindProfileByIdentifier] Failed to build request: #{e.message}"
        raise e
      end

      private

      def validate_types
        unless Constants::QUERY_IDENTIFIERS.include?(identifier_type)
          raise Errors::ArgumentError, "Identifier type is not supported, identifier_type=#{identifier_type}"
        end

        unless Constants::VIEW_TYPES.include?(view_type)
          raise Errors::ArgumentError, "View type is not supported, view_type=#{view_type}"
        end

        if identifier_type == Constants::ICN && view_type == Constants::CORRELATION_VIEW
          raise Errors::ArgumentError, "ICN searches only support the primary view, view=#{view_type}"
        end
      end

      def correlation_identifier
        case identifier_type
        when Constants::ICN
          identifier
        when Constants::IDME_UUID
          "#{identifier}^#{Constants::IDME_FULL_IDENTIFIER}"
        when Constants::LOGINGOV_UUID
          "#{identifier}^#{Constants::LOGINGOV_FULL_IDENTIFIER}"
        when Constants::MHV_UUID
          "#{identifier}^#{Constants::MHV_FULL_IDENTIFIER}"
        end
      end

      def build_body
        body = RequestHelper.build_control_act_process_element
        body << RequestHelper.build_code(code: Constants::FIND_PROFILE_CONTROL_ACT_PROCESS)
        body << query_by_parameter
        body
      end

      def query_by_parameter
        query_by_parameter = RequestHelper.build_query_by_parameter(search_type:, view_type:)
        query_by_parameter << build_parameter_list
      end

      def build_parameter_list
        el = RequestHelper.build_parameter_list_element
        el << RequestHelper.build_identifier(identifier: correlation_identifier, root:)
      end

      def root
        Constants::VA_ROOT_OID
      end
    end
  end
end
