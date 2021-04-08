# frozen_string_literal: true

require 'sentry_logging'
require 'identity/parsers/gc_ids'
require_relative 'parser_base'

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

      PATIENT_PERSON_PREFIX = 'patientPerson/'
      RELATIONSHIP_PREFIX = 'relationshipHolder1/'

      GENDER_XPATH = 'administrativeGenderCode/@code'
      DOB_XPATH = 'birthTime/@value'
      SSN_XPATH = 'asOtherIDs'
      NAME_XPATH = 'name'
      ADDRESS_XPATH = 'addr'
      PHONE = 'telecom'
      PERSON_TYPE = 'PERSON_TYPE'
      DISPLAY_NAME_XPATH = 'value/@displayName'
      PERSON_TYPE_CODE_XPATH = 'code/@code'
      ADMIN_OBSERVATION_XPATH = '*/administrativeObservation'

      HISTORICAL_ICN_XPATH = [
        'controlActProcess/subject', # matches SUBJECT_XPATH
        'registrationEvent',
        'replacementOf',
        'priorRegistration',
        'id'
      ].join('/').freeze

      ACKNOWLEDGEMENT_DETAIL_XPATH = 'acknowledgement/acknowledgementDetail/text'
      MULTIPLE_MATCHES_FOUND = 'Multiple Matches Found'

      PATIENT_RELATIONSHIP_XPATH = 'patientPerson/personalRelationship'

      # Creates a new parser instance.
      #
      # @param response [struct Faraday::Env] the Faraday response
      # @return [ProfileParser] an instance of this class
      def initialize(response)
        @original_body = locate_element(response.body, BODY_XPATH)
        @code = locate_element(@original_body, CODE_XPATH)
      end

      # MVI returns multiple match warnings if a query returns more than one match.
      #
      # @return [Boolean] has a multiple match warning?
      def multiple_match?
        acknowledgement_detail = locate_element(@original_body, ACKNOWLEDGEMENT_DETAIL_XPATH)
        return false unless acknowledgement_detail

        acknowledgement_detail.nodes.first == MULTIPLE_MATCHES_FOUND
      end

      # Parse the response and builds an MviProfile.
      #
      # @return [MviProfile] the profile from the parsed response
      def parse
        subject = locate_element(@original_body, SUBJECT_XPATH)
        return nil unless subject

        patient = locate_element(subject, PATIENT_XPATH)
        return nil unless patient

        build_mvi_profile(patient)
      end

      private

      def build_mvi_profile(patient)
        historical_icns = @original_body.locate(HISTORICAL_ICN_XPATH)
        profile_identity_hash = create_mvi_profile_identity(patient, PATIENT_PERSON_PREFIX)
        profile_ids_hash = create_mvi_profile_ids(patient, historical_icns)
        misc_hash = {
          search_token: locate_element(@original_body, 'id').attributes[:extension],
          relationships: parse_relationships(patient.locate(PATIENT_RELATIONSHIP_XPATH))
        }

        MPI::Models::MviProfile.new(profile_identity_hash.merge(profile_ids_hash).merge(misc_hash))
      end

      def parse_relationships(relationships_array)
        relationships_array.map { |relationship| build_relationship_mvi_profile(relationship) }
      end

      def build_relationship_mvi_profile(relationship)
        relationship_identity_hash = create_mvi_profile_identity(relationship, RELATIONSHIP_PREFIX)
        relationship_ids_hash = create_mvi_profile_ids(locate_element(relationship, RELATIONSHIP_PREFIX))

        MPI::Models::MviProfileRelationship.new(relationship_identity_hash.merge(relationship_ids_hash))
      end

      def create_mvi_profile_identity(person, person_prefix)
        person_component = locate_element(person, person_prefix)
        person_type = parse_person_type(person)
        name = parse_name(locate_element(person_component, NAME_XPATH))
        {
          given_names: name[:given],
          family_name: name[:family],
          suffix: name[:suffix],
          gender: locate_element(person_component, GENDER_XPATH),
          birth_date: locate_element(person_component, DOB_XPATH),
          ssn: parse_ssn(locate_element(person_component, SSN_XPATH)),
          address: parse_address(person_component),
          home_phone: parse_phone(person, person_prefix),
          person_type_code: person_type
        }
      end

      def create_mvi_profile_ids(patient, historical_icns = nil)
        full_mvi_ids = get_extensions(patient.locate('id'))
        parsed_mvi_ids = parse_xml_gcids(patient.locate('id'))
        log_inactive_mhv_ids(parsed_mvi_ids[:mhv_ids].to_a, parsed_mvi_ids[:active_mhv_ids].to_a)

        {
          full_mvi_ids: full_mvi_ids,
          icn: parsed_mvi_ids[:icn],
          mhv_ids: parsed_mvi_ids[:mhv_ids],
          active_mhv_ids: parsed_mvi_ids[:active_mhv_ids],
          edipi: sanitize_edipi(parsed_mvi_ids[:edipi]),
          participant_id: sanitize_id(parsed_mvi_ids[:vba_corp_id]),
          vha_facility_ids: parsed_mvi_ids[:vha_facility_ids],
          sec_id: parsed_mvi_ids[:sec_id],
          birls_id: sanitize_id(parsed_mvi_ids[:birls_id]),
          birls_ids: sanitize_id_array(parsed_mvi_ids[:birls_ids]),
          vet360_id: parsed_mvi_ids[:vet360_id],
          historical_icns: parse_xml_historical_icns(historical_icns),
          icn_with_aaid: parsed_mvi_ids[:icn_with_aaid],
          cerner_id: parsed_mvi_ids[:cerner_id],
          cerner_facility_ids: parsed_mvi_ids[:cerner_facility_ids]
        }
      end

      def get_extensions(id_array)
        id_array.map do |id_object|
          id_object.attributes[:extension]
        end
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
        if active_mhv_ids.size > 1
          log_message_to_sentry('Multiple active MHV correlation IDs present', :info,
                                ids: active_mhv_ids)
        end
      end

      # name can be a hash or an array of hashes with extra unneeded details
      # given may be an array if it includes middle name
      def parse_name(name)
        name = [name] unless name.is_a? Array
        name_element = [*name].first
        given = [*name_element.locate('given')].map { |el| el.nodes.first.capitalize }
        family = name_element.locate('family').first.nodes.first.capitalize
        suffix = name_element.locate('suffix')&.first&.nodes&.first&.capitalize
        { given: given, family: family, suffix: suffix }
      rescue => e
        Rails.logger.warn "MPI::Response.parse_name failed: #{e.message}"
        { given: nil, family: nil }
      end

      # other_ids can be hash or array of hashes
      def parse_ssn(other_ids)
        other_ids = [other_ids] unless other_ids.is_a? Array
        ssn_element = select_ssn_element(other_ids)
        return nil unless ssn_element

        ssn_element.attributes[:extension]
      rescue => e
        Rails.logger.warn "MPI::Response.parse_ssn failed: #{e.message}"
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
          return element.locate(DISPLAY_NAME_XPATH).first if element.locate(PERSON_TYPE_CODE_XPATH).first == PERSON_TYPE
        end
      end
    end
  end
end
