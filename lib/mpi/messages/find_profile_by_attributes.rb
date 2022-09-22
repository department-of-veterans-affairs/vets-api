# frozen_string_literal: true

require_relative 'request_helper'
require 'mpi/constants'

module MPI
  module Messages
    class FindProfileByAttributes
      attr_reader :given_names, :last_name, :birth_date, :gender, :ssn, :search_type, :orch_search, :edipi

      def initialize(profile:,
                     orch_search: false,
                     edipi: nil,
                     search_type: MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA)
        @given_names = profile[:given_names]
        @last_name = profile[:last_name]
        @birth_date = profile[:birth_date]
        @gender = profile[:gender]
        @ssn = profile[:ssn]
        @orch_search = orch_search
        @edipi = edipi
        @search_type = search_type
      end

      def perform
        validate_required_fields
        MPI::Messages::RequestBuilder.new(extension: MPI::Constants::FIND_PROFILE, body: build_body).perform
      rescue => e
        Rails.logger.error "[FindProfileByIdentifier] Failed to build request by identifier: #{e.message}"
        raise e
      end

      private

      def build_body
        body = build_control_act_process
        body << query_by_parameter
        body
      end

      def validate_required_fields
        missing_values = []
        missing_values << :given_names if given_names.blank?
        missing_values << :last_name if last_name.blank?
        missing_values << :birth_date if birth_date.blank?
        missing_values << :ssn if ssn.blank?
        missing_values << :edipi if edipi.blank? && orch_search
        raise ArgumentError, "Required values missing: #{missing_values}" if missing_values.present?
      end

      def build_control_act_process
        element = RequestHelper.build_control_act_process
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
        element << RequestHelper.build_assigned_person_ssn(ssn: ssn)
        element << RequestHelper.build_assigned_person_instance(given_names: given_names, family_name: last_name)
        element << RequestHelper.build_orchestrated_search(edipi: edipi) if orch_search
        element
      end

      def query_by_parameter
        query_by_parameter = RequestHelper.build_query_by_parameter(search_type: search_type)
        query_by_parameter << build_parameter_list
        query_by_parameter
      end

      def build_parameter_list
        element = RequestHelper.build_parameter_list_element
        element << RequestHelper.build_gender(gender: gender) if gender
        element << RequestHelper.build_birth_date(birth_date: birth_date)
        element << RequestHelper.build_ssn(ssn: ssn)
        element << RequestHelper.build_name(given_names: given_names, family_name: last_name)
        element << RequestHelper.build_vba_orchestration
        element
      end
    end
  end
end
