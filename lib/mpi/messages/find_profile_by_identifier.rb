# frozen_string_literal: true

require 'mpi/constants'
require_relative 'request_helper'
require_relative 'request_builder'

module MPI
  module Messages
    class FindProfileByIdentifier
      attr_reader :identifier, :search_type

      def initialize(identifier:, search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
        @identifier = identifier
        @search_type = search_type
      end

      def perform
        MPI::Messages::RequestBuilder.new(extension: MPI::Constants::FIND_PROFILE, body: build_body).perform
      rescue => e
        Rails.logger.error "[FindProfileByIdentifier] Failed to build request by identifier: #{e.message}"
        raise e
      end

      private

      def build_body
        body = RequestHelper.build_control_act_process
        body << query_by_parameter
        body
      end

      def query_by_parameter
        query_by_parameter = RequestHelper.build_query_by_parameter(search_type: search_type)
        query_by_parameter << build_parameter_list
      end

      def build_parameter_list
        el = RequestHelper.build_parameter_list_element
        el << RequestHelper.build_identifier(identifier: identifier)
      end
    end
  end
end
