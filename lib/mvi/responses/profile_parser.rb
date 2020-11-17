# frozen_string_literal: true

require 'sentry_logging'
require_relative 'id_parser'
require_relative 'historical_icn_parser'
require_relative 'parser_base'

module MVI
  module Responses
    # Parses a MVI response and returns a MviProfile
    class ProfileParser < ParserBase
      include SentryLogging

      BODY_XPATH = 'env:Envelope/env:Body/idm:PRPA_IN201306UV02'
      CODE_XPATH = 'acknowledgement/typeCode/@code'
      QUERY_XPATH = 'controlActProcess/queryByParameter'

      SSN_ROOT_ID = '2.16.840.1.113883.4.1'

      SUBJECT_XPATH = 'controlActProcess/subject'
      PATIENT_XPATH = 'registrationEvent/subject1/patient'
      STATUS_XPATH = 'statusCode/@code'
      GENDER_XPATH = 'patientPerson/administrativeGenderCode/@code'
      DOB_XPATH = 'patientPerson/birthTime/@value'
      SSN_XPATH = 'patientPerson/asOtherIDs'
      NAME_XPATH = 'patientPerson/name'
      ADDRESS_XPATH = 'patientPerson/addr'
      PHONE = 'patientPerson/telecom'

      ACKNOWLEDGEMENT_DETAIL_XPATH = 'acknowledgement/acknowledgementDetail/text'
      MULTIPLE_MATCHES_FOUND = 'Multiple Matches Found'

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

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def build_mvi_profile(patient)
        name = parse_name(get_patient_name(patient))
        full_mvi_ids = get_extensions(patient.locate('id'))
        parsed_mvi_ids = MVI::Responses::IdParser.new.parse(patient.locate('id'))
        log_inactive_mhv_ids(parsed_mvi_ids[:mhv_ids].to_a, parsed_mvi_ids[:active_mhv_ids].to_a)
        MVI::Models::MviProfile.new(
          given_names: name[:given],
          family_name: name[:family],
          suffix: name[:suffix],
          gender: locate_element(patient, GENDER_XPATH),
          birth_date: locate_element(patient, DOB_XPATH),
          ssn: parse_ssn(locate_element(patient, SSN_XPATH)),
          address: parse_address(patient),
          home_phone: parse_phone(patient),
          full_mvi_ids: full_mvi_ids,
          icn: parsed_mvi_ids[:icn],
          mhv_ids: parsed_mvi_ids[:mhv_ids],
          active_mhv_ids: parsed_mvi_ids[:active_mhv_ids],
          edipi: sanitize_edipi(parsed_mvi_ids[:edipi]),
          participant_id: sanitize_participant_id(parsed_mvi_ids[:vba_corp_id]),
          vha_facility_ids: parsed_mvi_ids[:vha_facility_ids],
          sec_id: parsed_mvi_ids[:sec_id],
          birls_id: sanitize_birls_id(parsed_mvi_ids[:birls_id]),
          birls_ids: parsed_mvi_ids[:birls_ids].map { |id| sanitize_birls_id(id) }.compact,
          vet360_id: parsed_mvi_ids[:vet360_id],
          historical_icns: MVI::Responses::HistoricalIcnParser.new(@original_body).get_icns,
          icn_with_aaid: parsed_mvi_ids[:icn_with_aaid],
          search_token: locate_element(@original_body, 'id').attributes[:extension],
          cerner_id: parsed_mvi_ids[:cerner_id],
          cerner_facility_ids: parsed_mvi_ids[:cerner_facility_ids]
        )
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

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

      def get_patient_name(patient)
        locate_element(patient, NAME_XPATH)
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
        Rails.logger.warn "MVI::Response.parse_name failed: #{e.message}"
        { given: nil, family: nil }
      end

      # other_ids can be hash or array of hashes
      def parse_ssn(other_ids)
        other_ids = [other_ids] unless other_ids.is_a? Array
        ssn_element = select_ssn_element(other_ids)
        return nil unless ssn_element

        ssn_element.attributes[:extension]
      rescue => e
        Rails.logger.warn "MVI::Response.parse_ssn failed: #{e.message}"
        nil
      end

      def parse_address(patient)
        el = locate_element(patient, ADDRESS_XPATH)
        return nil unless el

        address_hash = el.nodes.map { |n| { n.value.snakecase.to_sym => n.nodes.first } }.reduce({}, :merge)
        address_hash[:street] = address_hash.delete :street_address_line
        MVI::Models::MviProfileAddress.new(address_hash)
      end

      def parse_phone(patient)
        el = locate_element(patient, PHONE)
        return nil unless el

        el.attributes[:value]
      end

      def select_ssn_element(other_ids)
        other_ids.each do |oi|
          node = oi.nodes.select { |n| n.attributes[:root] == SSN_ROOT_ID }
          return node.first unless node.empty?
        end
      end
    end
  end
end
