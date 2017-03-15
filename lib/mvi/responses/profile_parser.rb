# frozen_string_literal: true
require_relative 'base'

module MVI
  module Responses
    class ProfileParser
      SSN_ROOT_ID = '2.16.840.1.113883.4.1'
      CORRELATION_ROOT_ID = '2.16.840.1.113883.4.349'
      EDIPI_ROOT_ID = '2.16.840.1.113883.3.42.10001.100001.12'

      SUBJECT_XPATH = 'controlActProcess/subject'
      PATIENT_XPATH = 'registrationEvent/subject1/patient'
      STATUS_XPATH = 'statusCode/@code'
      GENDER_XPATH = 'patientPerson/administrativeGenderCode/@code'
      DOB_XPATH = 'patientPerson/birthTime/@value'
      SSN_XPATH = 'patientPerson/asOtherIDs'
      NAME_XPATH = 'patientPerson/name'
      ADDRESS_XPATH = 'patientPerson/addr'
      PHONE = 'patientPerson/telecom'

      attr_writer :xml

      def initialize(xml)
        @xml = xml
      end

      def parse
        subject = locate_element(@xml, SUBJECT_XPATH)
        return nil unless subject
        patient = locate_element(subject, PATIENT_XPATH)
        return nil unless patient
        build_mvi_profile(patient)
      end

      private

      def build_mvi_profile(patient)
        name = parse_name(get_patient_name(patient))
        correlation_ids = map_correlation_ids(patient.locate('id'))
        MviProfile.new(
          given_names: name[:given],
          family_name: name[:family],
          suffix: name[:suffix],
          gender: locate_element(patient, GENDER_XPATH),
          birth_date: locate_element(patient, DOB_XPATH),
          ssn: parse_ssn(locate_element(patient, SSN_XPATH)),
          address: parse_address(patient),
          home_phone: parse_phone(patient),
          icn: correlation_ids[:icn],
          mhv_ids: correlation_ids[:mhv_ids],
          edipi: correlation_ids[:edipi],
          participant_id: correlation_ids[:vba_corp_id]
        )
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
        MviProfileAddress.new(address_hash)
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

      # MVI correlation id source id relationships:
      # {source id}^{id type}^{assigning authority}^{assigning facility}^{id status}
      # NI = national identifier, PI = patient identifier
      def map_correlation_ids(ids)
        ids = ids.map(&:attributes)
        {
          icn: select_extension(ids, /^\w+\^NI\^\w+\^\w+\^\w+$/, CORRELATION_ROOT_ID)&.first,
          mhv_ids: select_extension(ids, /^\w+\^PI\^200MH.{0,1}\^\w+\^\w+$/, CORRELATION_ROOT_ID),
          edipi: select_extension(ids, /^\w+\^NI\^200DOD\^USDOD\^\w+$/, EDIPI_ROOT_ID)&.first,
          vba_corp_id: select_extension(ids, /^\w+\^PI\^200CORP\^USVBA\^\w+$/, CORRELATION_ROOT_ID)&.first
        }
      end

      def select_extension(ids, pattern, root)
        extensions = ids.select do |id|
          id[:extension] =~ pattern && id[:root] == root
        end
        return nil if extensions.empty?
        extensions.map { |e| e[:extension].split('^')&.first }
      end

      def locate_element(el, path)
        return nil unless el
        el.locate(path)&.first
      end
    end
  end
end
