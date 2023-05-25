# frozen_string_literal: true

require_relative 'request_helper'
require_relative 'request_builder'
require 'mpi/constants'

module MPI
  module Messages
    class FindProfileByFacility
      attr_reader :facility_id, :vista_id, :search_type

      def initialize(facility_id:, vista_id:, search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
        @facility_id = facility_id
        @vista_id = vista_id
        @search_type = search_type
      end

      def perform
        MPI::Messages::RequestBuilder.new(extension: MPI::Constants::FIND_PROFILE, body: build_body).perform
      rescue => e
        Rails.logger.error "[FindProfileByFacility] Failed to build request: #{e.message}"
        raise e
      end

      private

      def build_body
        body = RequestHelper.build_control_act_process_element
        body << RequestHelper.build_code(code: MPI::Constants::FIND_PROFILE_CONTROL_ACT_PROCESS)
        body << query_by_parameter
        body
      end

      def query_by_parameter
        query_by_parameter = RequestHelper.build_query_by_parameter(search_type:)
        query_by_parameter << build_parameter_list
      end

      def build_parameter_list
        element = RequestHelper.build_parameter_list_element
        element << RequestHelper.build_identifier(identifier:, root:)
      end

      def root
        MPI::Constants::VA_ROOT_OID
      end

      def identifier
        "#{vista_id}^PI^#{facility_id}^#{MPI::Constants::ACTIVE_VHA_IDENTIFIER}"
      end
    end
  end
end
