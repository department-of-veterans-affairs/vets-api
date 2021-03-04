# frozen_string_literal: true

require_relative 'gc_ids_constants'
require_relative 'gc_ids_helper'

module Identity
  module Parsers
    module GCIds
      include Identity::Parsers::GCIdsConstants
      include Identity::Parsers::GCIdsHelper

      # @param ids [Array] An array of XML objects representing ids to parse
      # @return [Hash] An hash representing the parsed ids
      def parse_xml_gcids(ids)
        return unless ids.is_a? Array

        ids = ids.map(&:attributes)

        birls_ids = select_ids(select_extension(ids, BIRLS_IDS_REGEX, VA_ROOT_OID)) || []

        {
          icn: select_ids(select_extension(ids, PERMANENT_ICN_REGEX, VA_ROOT_OID))&.first,
          sec_id: select_ids(select_extension(ids, SEC_ID_REGEX, VA_ROOT_OID))&.first,
          mhv_ids: select_ids(select_extension(ids, MHV_IDS_REGEX, VA_ROOT_OID)),
          active_mhv_ids: select_ids(select_extension(ids, ACTIVE_MHV_IDS_REGEX, VA_ROOT_OID)),
          edipi: select_ids(select_extension(ids, EDIPI_REGEX, DOD_ROOT_OID))&.first,
          vba_corp_id: select_ids(select_extension(ids, VBA_CORP_ID_REGEX, VA_ROOT_OID))&.first,
          idme_id: select_ids(select_extension(ids, IDME_ID_REGEX, VA_ROOT_OID))&.first,
          vha_facility_ids: select_facilities(select_extension(ids, VHA_FACILITY_IDS_REGEX, VA_ROOT_OID)),
          cerner_facility_ids: select_facilities(select_extension(ids, CERNER_FACILITY_IDS_REGEX, VA_ROOT_OID)),
          cerner_id: select_ids(select_extension(ids, CERNER_ID_REGEX, VA_ROOT_OID))&.first,
          birls_ids: birls_ids,
          birls_id: birls_ids&.first,
          vet360_id: select_ids(select_extension(ids, VET360_ID_REGEX, VA_ROOT_OID))&.first,
          icn_with_aaid: select_icn_with_aaid(ids)
        }
      end

      # @param historical_icn_ids [Array<Ox::Element>]An array of XML Ox objects representing historical icns to parse
      # @return [Array<String>] An array of strings representing the parsed historical icn ids
      # for example, ['1000123457V123456']
      # @return [Array] Empty array if icn regex not parsed
      def parse_xml_historical_icns(historical_icn_ids)
        return [] unless historical_icn_ids.is_a? Array

        select_ids(select_extension(historical_icn_ids, ICN_REGEX, VA_ROOT_OID)) || []
      end

      # @param ids [String] A string representing ids to parse
      # @param root_oid [String] A string representing the originating service for the ids
      # @return [Hash] An hash representing the parsed ids
      def parse_string_gcids(ids, root_oid = VA_ROOT_OID)
        return unless ids

        mapped_ids = ids.split(IDS_SPLIT_TOKEN).map do |id|
          OpenStruct.new(attributes: { extension: id, root: root_oid })
        end
        parse_xml_gcids(mapped_ids)
      end

      private

      def select_ids(extensions)
        return nil if extensions.empty?

        extensions.map { |e| e[:extension].split(IDENTIFIERS_SPLIT_TOKEN).first }
      end

      def select_facilities(extensions)
        return nil if extensions.empty?

        extensions.map { |e| e[:extension].split(IDENTIFIERS_SPLIT_TOKEN)&.third }
      end

      def select_extension(ids, pattern, root)
        ids.select do |id|
          id[:extension] =~ pattern && id[:root] == root
        end
      end

      # @param ids [Array] An array of hashes, of the format {:extension=>'string', :root=>'string'}
      # @return [String] A string representing an icn_with_aaid, with the ID status removed,
      # for example, '12345678901234567^NI^200M^USVHA'
      # @return [Nil] If icn regex not parsed, or status not applicable, return nil
      def select_icn_with_aaid(ids)
        extension = select_extension(ids, PERMANENT_ICN_REGEX, VA_ROOT_OID).pop
        return unless extension

        *identifiers_array, status = extension.dig(:extension).split(IDENTIFIERS_SPLIT_TOKEN)
        return unless status == 'P'

        identifiers_array.join(IDENTIFIERS_SPLIT_TOKEN)
      end
    end
  end
end
