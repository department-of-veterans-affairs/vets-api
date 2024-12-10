# frozen_string_literal: true

require_relative 'request_helper'
require_relative 'request_builder'
require 'formatters/date_formatter'

module MPI
  module Messages
    class UpdateProfileMessage
      attr_reader :first_name, :last_name, :ssn, :birth_date, :idme_uuid, :logingov_uuid, :icn, :edipi, :email, :address

      # rubocop:disable Metrics/ParameterLists
      def initialize(first_name:,
                     last_name:,
                     ssn:,
                     icn:,
                     email:,
                     birth_date:,
                     address: nil,
                     idme_uuid: nil,
                     logingov_uuid: nil,
                     edipi: nil)
        @first_name = first_name
        @last_name = last_name
        @ssn = ssn
        @icn = icn
        @email = email
        @birth_date = birth_date
        @address = address
        @idme_uuid = idme_uuid
        @logingov_uuid = logingov_uuid
        @edipi = edipi
      end
      # rubocop:enable Metrics/ParameterLists

      def perform
        validate_required_fields
        MPI::Messages::RequestBuilder.new(extension: MPI::Constants::UPDATE_PROFILE, body: build_body).perform
      rescue => e
        Rails.logger.error "[UpdateProfileMessage] Failed to build request: #{e.message}"
        raise e
      end

      private

      def validate_required_fields
        missing_values = []
        missing_values << :last_name if last_name.blank?
        missing_values << :email if email.blank?
        missing_values << :birth_date if birth_date.blank?
        missing_values << :icn if icn.blank?
        missing_values << :uuid if logingov_uuid.blank? && edipi.blank? && idme_uuid.blank?
        raise Errors::ArgumentError, "Required values missing: #{missing_values}" if missing_values.present?
      end

      def build_body
        element = RequestHelper.build_control_act_process_element
        element << build_subject
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
        if address.present?
          element << RequestHelper.build_patient_person_address(street: combined_street,
                                                                state: address[:state],
                                                                city: address[:city],
                                                                postal_code: address[:postal_code],
                                                                country: address[:country])
        end
        element << RequestHelper.build_identifier(identifier:, root: identifier_root)
        element << RequestHelper.build_telecom(type: email_type, value: email)
        if ssn.present?
          element << RequestHelper.build_patient_identifier(identifier: ssn, root: ssn_root, class_code: ssn_class_code)
        end
        element << RequestHelper.build_patient_identifier(identifier:,
                                                          root: identifier_root,
                                                          class_code: identifier_class_code)
        element
      end

      def combined_street
        [address[:street], address[:street2]].compact.join(' ')
      end

      def identifier
        "#{csp_uuid}^#{csp_identifier}"
      end

      def csp_identifier
        if edipi
          Constants::DSLOGON_FULL_IDENTIFIER
        elsif logingov_uuid
          Constants::LOGINGOV_FULL_IDENTIFIER
        else
          Constants::IDME_FULL_IDENTIFIER
        end
      end

      def csp_uuid
        edipi || logingov_uuid || idme_uuid
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

      def identifier_class_code
        'PAT'
      end

      def email_type
        'H'
      end

      def identifier_root
        if edipi
          Constants::DOD_ROOT_OID
        else
          MPI::Constants::VA_ROOT_OID
        end
      end

      def icn_root
        MPI::Constants::VA_ROOT_OID
      end
    end
  end
end
