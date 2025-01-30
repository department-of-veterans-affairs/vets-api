# frozen_string_literal: true

require_relative 'request_helper'
require_relative 'request_builder'
require 'mpi/constants'

module MPI
  module Messages
    class FindProfileByAttributes
      attr_reader :first_name, :middle_name, :last_name, :birth_date, :gender, :ssn, :search_type, :orch_search, :edipi

      # rubocop:disable Metrics/ParameterLists
      def initialize(first_name:,
                     last_name:,
                     birth_date:,
                     ssn:,
                     middle_name: nil,
                     gender: nil,
                     orch_search: false,
                     edipi: nil,
                     search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
        @first_name = first_name
        @middle_name = middle_name
        @last_name = last_name
        @birth_date = birth_date
        @gender = gender
        @ssn = ssn
        @orch_search = orch_search
        @edipi = edipi
        @search_type = search_type
      end

      def perform
        validate_required_fields
        MPI::Messages::RequestBuilder.new(extension: MPI::Constants::FIND_PROFILE, body: build_body).perform
      rescue => e
        Rails.logger.error "[FindProfileByAttributes] Failed to build request: #{e.message}"
        raise e
      end
      # rubocop:enable Metrics/ParameterLists

      private

      def given_names
        @given_names ||= [first_name, middle_name].compact
      end

      def build_body
        body = build_control_act_process
        body << query_by_parameter
        body
      end

      def validate_required_fields
        missing_values = []
        missing_values << :first_name if first_name.blank?
        missing_values << :last_name if last_name.blank?
        missing_values << :birth_date if birth_date.blank?
        missing_values << :ssn if ssn.blank?
        missing_values << :edipi if edipi.blank? && orch_search
        raise Errors::ArgumentError, "Required values missing: #{missing_values}" if missing_values.present?
      end

      def build_control_act_process
        element = RequestHelper.build_control_act_process_element
        element << RequestHelper.build_code(code: MPI::Constants::FIND_PROFILE_CONTROL_ACT_PROCESS)
        element << build_data_enterer
        element
      end

      def build_data_enterer
        element = RequestHelper.build_data_enterer_element
        element << build_assigned_person
        element
      end

      def build_assigned_person
        element = RequestHelper.build_assigned_person_element
        element << RequestHelper.build_assigned_person_ssn(ssn:)
        element << RequestHelper.build_assigned_person_instance(given_names:, family_name: last_name)
        element << RequestHelper.build_represented_organization(edipi:) if orch_search
        element
      end

      def query_by_parameter
        query_by_parameter = RequestHelper.build_query_by_parameter(search_type:)
        query_by_parameter << build_parameter_list
        query_by_parameter
      end

      def build_parameter_list
        element = RequestHelper.build_parameter_list_element
        element << RequestHelper.build_gender(gender:) if gender
        element << RequestHelper.build_birth_date(birth_date:)
        element << RequestHelper.build_ssn(ssn:)
        element << RequestHelper.build_name(given_names:, family_name: last_name)
        element << RequestHelper.build_vba_orchestration
        element
      end
    end
  end
end
