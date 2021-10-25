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

        ids_mapped = ids.map(&:attributes)

        ID_MAPPINGS.map do |id_to_parse, parse_options|
          extension = select_extension(ids_mapped, parse_options[:regex], parse_options[:root_oid])
          parsed_ids =
            case parse_options[:type]
            when :single_id
              select(extension, :id)&.first
            when :multiple_ids
              select(extension, :id)
            when :facility
              select(extension, :assigning_facility)
            when :icn_with_aaid
              select_icn_with_aaid(extension)
            when :facility_to_ids
              build_hash(extension, %i[assigning_facility id])
            end
          { id_to_parse => parsed_ids }
        end.reduce(:merge)
      end

      # @param historical_icn_ids [Array<Ox::Element>]An array of XML Ox objects representing historical icns to parse
      # @return [Array<String>] An array of strings representing the parsed historical icn ids
      # for example, ['1000123457V123456']
      # @return [Array] Empty array if icn regex not parsed
      def parse_xml_historical_icns(historical_icn_ids)
        return [] unless historical_icn_ids.is_a? Array

        select(select_extension(historical_icn_ids, ICN_REGEX, VA_ROOT_OID), :id) || []
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

      # Extension is expected to be formatted as: <id>^<id_type>^<assigning_facility>^<assigning_authority>^<id_state>
      def select(extensions, select_token = :id)
        return nil if extensions.empty?

        extensions.map { |e| e[:extension].split(IDENTIFIERS_SPLIT_TOKEN)[select_token_position(select_token)] }
      end

      def select_token_position(token_symbol)
        case token_symbol
        when :id then 0
        when :id_type then 1
        when :assigning_facility then 2
        when :assigning_authority then 3
        when :id_state then 4
        end
      end

      def select_extension(ids, pattern, root)
        ids.select do |id|
          id[:extension] =~ pattern && id[:root] == root
        end
      end

      # @param extension [Array] An array of hashes, of the format {:extension=>'string', :root=>'string'}
      # @return [String] A string representing an icn_with_aaid, with the ID status removed,
      # for example, '12345678901234567^NI^200M^USVHA'
      # @return [Nil] If icn regex not parsed, or status not applicable, return nil
      def select_icn_with_aaid(extension)
        return unless extension.is_a?(Array) && extension.present?

        *identifiers_array, status = extension.first[:extension].split(IDENTIFIERS_SPLIT_TOKEN)
        return unless status == 'P'

        identifiers_array.join(IDENTIFIERS_SPLIT_TOKEN)
      end

      def build_hash(extensions, (key, value))
        return nil if extensions.empty?

        key_token = select_token_position(key)
        value_token = select_token_position(value)
        ids_hash = Hash.new { |h, k| h[k] = [] }

        extensions.each_with_object(ids_hash) do |e, hsh|
          split_string = e[:extension].split(IDENTIFIERS_SPLIT_TOKEN)
          hsh[split_string[key_token]] << split_string[value_token]
        end
      end
    end
  end
end
