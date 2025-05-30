# frozen_string_literal: true

require_relative 'request_helper'
require_relative 'request_builder'
require 'formatters/date_formatter'

module MPI
  module Messages
    class AddPersonProxyAddMessage
      attr_reader :first_name, :last_name, :ssn, :birth_date, :icn, :edipi, :search_token, :as_agent

      # rubocop:disable Metrics/ParameterLists
      def initialize(first_name:,
                     last_name:,
                     ssn:,
                     birth_date:,
                     edipi:,
                     icn:,
                     search_token:,
                     as_agent: false)
        @first_name = first_name
        @last_name = last_name
        @ssn = ssn
        @icn = icn
        @birth_date = birth_date
        @edipi = edipi
        @search_token = search_token
        @as_agent = as_agent
      end
      # rubocop:enable Metrics/ParameterLists

      def perform
        validate_required_fields
        MPI::Messages::RequestBuilder.new(extension: MPI::Constants::ADD_PERSON,
                                          body: build_body,
                                          search_token:,
                                          as_agent:).perform
      rescue => e
        Rails.logger.error "[AddPersonProxyAddMessage] Failed to build request: #{e.message}"
        raise e
      end

      private

      def validate_required_fields
        missing_values = []
        missing_values << :first_name if first_name.blank?
        missing_values << :last_name if last_name.blank?
        missing_values << :ssn if ssn.blank?
        missing_values << :birth_date if birth_date.blank?
        missing_values << :icn if icn.blank?
        missing_values << :edipi if edipi.blank?
        missing_values << :search_token if search_token.blank?
        raise Errors::ArgumentError, "Required values missing: #{missing_values}" if missing_values.present?
      end

      def build_body
        element = RequestHelper.build_control_act_process_element
        element << build_data_enterer
        element << build_subject
        element
      end

      def build_data_enterer
        element = RequestHelper.build_data_enterer_element
        element << build_assigned_person
        element
      end

      def build_assigned_person
        element = RequestHelper.build_assigned_person_element
        element << RequestHelper.build_identifier(identifier: icn_with_aaid, root: icn_root)
        element << RequestHelper.build_assigned_person_instance(given_names: [first_name], family_name: last_name)
        element << RequestHelper.build_represented_organization(edipi:)
        element
      end

      def build_subject
        element = RequestHelper.build_subject_element
        element << build_registration_event
        element
      end

      def build_registration_event
        element = RequestHelper.build_registration_event_element
        element << RequestHelper.build_id_null_flavor(type: null_flavor_type)
        element << RequestHelper.build_status_code
        element << build_subject_1
        element << RequestHelper.build_custodian
        element
      end

      def build_subject_1
        element = RequestHelper.build_subject_1_element
        element << build_patient
        element
      end

      def build_patient
        element = RequestHelper.build_patient_element
        element << RequestHelper.build_identifier(identifier: icn_with_aaid, root: icn_root)
        element << RequestHelper.build_status_code
        element << build_patient_person
        element << RequestHelper.build_provider_organization
        element
      end

      def build_patient_person
        element = RequestHelper.build_patient_person_element
        element << RequestHelper.build_patient_person_name(given_names: [first_name], family_name: last_name)
        element << RequestHelper.build_patient_person_birth_date(birth_date:)
        element << RequestHelper.build_patient_identifier(identifier: ssn, root: ssn_root, class_code: ssn_class_code)
        element << RequestHelper.build_patient_person_proxy_add
        element
      end

      def null_flavor_type
        'NA'
      end

      def icn_with_aaid
        "#{icn}^NI^200M^USVHA^P"
      end

      def ssn_root
        '2.16.840.1.113883.4.1'
      end

      def ssn_class_code
        'SSN'
      end

      def icn_root
        MPI::Constants::VA_ROOT_OID
      end
    end
  end
end
