# frozen_string_literal: true

require 'sentry_logging'
require 'identity/parsers/gc_ids'
require_relative 'parser_base'
require 'mpi/models/mvi_profile'

module MPI
  module Responses
    # Parses a MVI response and returns a MviProfile
    class ProfileParser < ParserBase
      include SentryLogging
      include Identity::Parsers::GCIds

      BODY_XPATH = 'env:Envelope/env:Body/idm:PRPA_IN201306UV02'
      CODE_XPATH = 'acknowledgement/typeCode/@code'
      QUERY_XPATH = 'controlActProcess/queryByParameter'

      SSN_ROOT_ID = '2.16.840.1.113883.4.1'

      SUBJECT_XPATH = 'controlActProcess/subject'
      PATIENT_XPATH = 'registrationEvent/subject1/patient'
      STATUS_XPATH = 'statusCode/@code'
      CONFIDENTIALITY_CODE_XPATH = 'confidentialityCode/@code'
      ID_THEFT_INDICATOR = 'ID_THEFT^TRUE'

      PATIENT_PERSON_PREFIX = 'patientPerson/'
      RELATIONSHIP_PREFIX = 'relationshipHolder1/'

      GENDER_XPATH = 'administrativeGenderCode/@code'
      DOB_XPATH = 'birthTime/@value'
      SSN_XPATH = 'asOtherIDs'
      NAME_XPATH = 'name'
      NAME_LEGAL_INDICATOR = 'L'
      ADDRESS_XPATH = 'addr'
      DECEASED_XPATH = 'deceasedTime/@value'
      PHONE = 'telecom'
      PERSON_TYPE = 'PERSON_TYPE'
      PERSON_TYPE_SEPERATOR = '~'
      PERSON_TYPE_VALUE_XPATH = 'value/@code'
      PERSON_TYPE_CODE_XPATH = 'code/@code'
      ADMIN_OBSERVATION_XPATH = '*/administrativeObservation'

      ACKNOWLEDGEMENT_DETAIL_XPATH = 'acknowledgement/acknowledgementDetail/text'
      ACKNOWLEDGEMENT_TARGET_MESSAGE_ID_EXTENSION_XPATH = 'acknowledgement/targetMessage/id/@extension'
      MULTIPLE_MATCHES_FOUND = 'Multiple Matches Found'

      PATIENT_RELATIONSHIP_XPATH = 'patientPerson/personalRelationship'

      def initialize(response)
        @transaction_id = response.response_headers['x-global-transaction-id']
        @original_body = locate_element(response.body, BODY_XPATH)
        @code = locate_element(@original_body, CODE_XPATH)
      end

      def multiple_match?
        acknowledgement_detail = locate_element(@original_body, ACKNOWLEDGEMENT_DETAIL_XPATH)
        return false unless acknowledgement_detail

        acknowledgement_detail.nodes.first == MULTIPLE_MATCHES_FOUND
      end

      def no_match?
        locate_element(@original_body, SUBJECT_XPATH).blank?
      end

      def parse
        subject = locate_element(@original_body, SUBJECT_XPATH)
        return MPI::Models::MviProfile.new({ transaction_id: @transaction_id }) unless subject

        patient = locate_element(subject, PATIENT_XPATH)
        return MPI::Models::MviProfile.new({ transaction_id: @transaction_id }) unless patient

        build_mpi_profile(patient)
      end

      def error_details
        error_details = {
          ack_detail_code: @code,
          id_extension: locate_element(@original_body, ACKNOWLEDGEMENT_TARGET_MESSAGE_ID_EXTENSION_XPATH),
          transaction_id: @transaction_id,
          error_texts: []
        }
        error_text_nodes = locate_elements(@original_body, ACKNOWLEDGEMENT_DETAIL_XPATH)
        if error_text_nodes.nil?
          error_details[:error_texts] = error_text_nodes
        else
          error_text_nodes.each do |node|
            error_text = node.text || node&.nodes&.first&.value
            error_details[:error_texts].append(error_text) unless error_details[:error_texts].include?(error_text)
          end
        end
        { error_details: }
      end

      private

      def build_mpi_profile(patient)
        profile_identity_hash = create_mpi_profile_identity(patient, PATIENT_PERSON_PREFIX)
        profile_ids_hash = create_mpi_profile_ids(patient)
        misc_hash = {
          search_token: locate_element(@original_body, 'id').attributes[:extension],
          relationships: parse_relationships(patient.locate(PATIENT_RELATIONSHIP_XPATH)),
          id_theft_flag: parse_id_theft_flag(patient),
          transaction_id: @transaction_id
        }
        mpi_attribute_validations(profile_identity_hash, profile_ids_hash)

        MPI::Models::MviProfile.new(profile_identity_hash.merge(profile_ids_hash).merge(misc_hash))
      end

      def parse_relationships(relationships_array)
        relationships_array.map { |relationship| build_relationship_mpi_profile(relationship) }
      end

      def build_relationship_mpi_profile(relationship)
        relationship_identity_hash = create_mpi_profile_identity(relationship,
                                                                 RELATIONSHIP_PREFIX,
                                                                 optional_params: true)
        relationship_ids_hash = create_mpi_profile_ids(locate_element(relationship, RELATIONSHIP_PREFIX))

        MPI::Models::MviProfileRelationship.new(relationship_identity_hash.merge(relationship_ids_hash))
      end

      def parse_id_theft_flag(patient)
        code = locate_element(patient, CONFIDENTIALITY_CODE_XPATH)
        code == ID_THEFT_INDICATOR
      end

      def create_mpi_profile_identity(person, person_prefix, optional_params: false)
        person_component = locate_element(person, person_prefix)
        person_types = parse_person_type(person)
        name = parse_name(locate_elements(person_component, NAME_XPATH), optional_params)
        {
          given_names: name[:given],
          family_name: name[:family],
          suffix: name[:suffix],
          gender: locate_element(person_component, GENDER_XPATH),
          birth_date: locate_element(person_component, DOB_XPATH),
          deceased_date: locate_element(person_component, DECEASED_XPATH),
          ssn: parse_ssn(locate_element(person_component, SSN_XPATH), optional_params),
          address: parse_address(person_component),
          home_phone: parse_phone(person, person_prefix),
          person_types:
        }
      end

      def create_mpi_profile_ids(patient)
        full_mvi_ids = get_extensions(patient.locate('id'))
        parsed_mvi_ids = parse_xml_gcids(patient.locate('id'))
        create_ids_obj(full_mvi_ids, parsed_mvi_ids)
      end

      def create_ids_obj(full_mvi_ids, parsed_mvi_ids)
        {
          full_mvi_ids:
        }.merge(parse_single_ids(parsed_mvi_ids).merge(parse_multiple_ids(parsed_mvi_ids)))
      end

      def parse_single_ids(parsed_mvi_ids)
        {
          icn: parsed_mvi_ids[:icn],
          edipi: sanitize_edipi(parsed_mvi_ids[:edipi]),
          participant_id: sanitize_id(parsed_mvi_ids[:vba_corp_id]),
          mhv_ien: sanitize_id(parsed_mvi_ids[:mhv_ien]),
          sec_id: parsed_mvi_ids[:sec_id],
          birls_id: sanitize_id(parsed_mvi_ids[:birls_id]),
          vet360_id: parsed_mvi_ids[:vet360_id],
          icn_with_aaid: parsed_mvi_ids[:icn_with_aaid],
          cerner_id: parsed_mvi_ids[:cerner_id]
        }
      end

      def parse_multiple_ids(parsed_mvi_ids)
        {
          mhv_ids: parsed_mvi_ids[:mhv_ids],
          active_mhv_ids: parsed_mvi_ids[:active_mhv_ids],
          edipis: sanitize_id_array(parsed_mvi_ids[:edipis]),
          participant_ids: sanitize_id_array(parsed_mvi_ids[:vba_corp_ids]),
          mhv_iens: sanitize_id_array(parsed_mvi_ids[:mhv_iens]),
          vha_facility_ids: parsed_mvi_ids[:vha_facility_ids],
          vha_facility_hash: parsed_mvi_ids[:vha_facility_hash],
          birls_ids: sanitize_id_array(parsed_mvi_ids[:birls_ids]),
          cerner_facility_ids: parsed_mvi_ids[:cerner_facility_ids]
        }
      end

      def get_extensions(id_array)
        id_array.map do |id_object|
          id_object.attributes[:extension]
        end
      end

      def mpi_attribute_validations(identity_hash, ids_hash)
        log_inactive_mhv_ids(ids_hash[:mhv_ids].to_a, ids_hash[:active_mhv_ids].to_a)
        validate_dob(identity_hash[:birth_date], ids_hash[:icn])
      end

      def log_inactive_mhv_ids(mhv_ids, active_mhv_ids)
        return if mhv_ids.blank?

        if (mhv_ids - active_mhv_ids).present?
          log_message_to_sentry('Inactive MHV correlation IDs present', :info,
                                ids: mhv_ids)
        end
        unless active_mhv_ids.include?(mhv_ids.first)
          log_message_to_sentry('Returning inactive MHV correlation ID as first identifier', :warn,
                                ids: mhv_ids)
        end
        if active_mhv_ids.uniq.size > 1
          log_message_to_sentry('Multiple active MHV correlation IDs present', :info,
                                ids: active_mhv_ids)
        end
      end

      def validate_dob(dob, icn)
        Date.iso8601(dob)
      rescue Date::Error
        Rails.logger.warn 'MPI::Response.parse_dob failed', { dob:, icn: }
      end

      def parse_name(name, optional_params)
        name_element = parse_legal_name(name)
        return { given: nil, family: nil } if optional_params && name_element.blank?

        given = [*name_element.locate('given')].map { |el| el.nodes.first.capitalize }
        family = name_element.locate('family').first.nodes.first.capitalize
        suffix = name_element.locate('suffix')&.first&.nodes&.first&.capitalize
        { given:, family:, suffix: }
      rescue
        Rails.logger.warn 'MPI::Response.parse_name failed'
        { given: nil, family: nil }
      end

      def parse_legal_name(name_array)
        name_array.find { |name_element| name_element if name_element.attributes[:use] == NAME_LEGAL_INDICATOR }
      end

      # other_ids can be hash or array of hashes
      def parse_ssn(other_ids, optional_params)
        return nil if optional_params && other_ids.blank?

        other_ids = [other_ids] unless other_ids.is_a? Array
        ssn_element = select_ssn_element(other_ids)
        return nil unless ssn_element

        ssn_element.attributes[:extension]
      rescue
        Rails.logger.warn 'MPI::Response.parse_ssn failed'
        nil
      end

      def parse_address(person)
        el = locate_element(person, ADDRESS_XPATH)
        return nil unless el

        address_hash = el.nodes.map { |n| { n.value.snakecase.to_sym => n.nodes.first } }.reduce({}, :merge)
        address_hash[:street] = address_hash.delete :street_address_line
        MPI::Models::MviProfileAddress.new(address_hash)
      end

      def parse_phone(person, person_prefix)
        el = locate_element(person, PHONE) || locate_element(person, person_prefix + PHONE)
        return nil unless el

        el.attributes[:value]
      end

      def select_ssn_element(other_ids)
        other_ids.each do |oi|
          node = oi.nodes.select { |n| n.attributes[:root] == SSN_ROOT_ID }
          return node.first unless node.empty?
        end
      end

      def parse_person_type(person)
        person.locate(ADMIN_OBSERVATION_XPATH).each do |element|
          if element.locate(PERSON_TYPE_CODE_XPATH).first == PERSON_TYPE
            person_type_string = element.locate(PERSON_TYPE_VALUE_XPATH).first
            return person_type_string&.split(PERSON_TYPE_SEPERATOR) || []
          end
        end
      end
    end
  end
end
