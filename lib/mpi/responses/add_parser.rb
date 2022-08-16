# frozen_string_literal: true

require 'sentry_logging'
require_relative 'parser_base'
require 'identity/parsers/gc_ids'

module MPI
  module Responses
    # Parses an MVI response and returns an MviProfile
    class AddParser < ParserBase
      include SentryLogging
      include Identity::Parsers::GCIds

      ACKNOWLEDGEMENT_DETAIL_CODE_XPATH = 'acknowledgement/acknowledgementDetail/code'
      ACKNOWLEDGEMENT_DETAIL_TEXT_XPATH = 'acknowledgement/acknowledgementDetail/text'
      ACKNOWLEDGEMENT_TARGET_MESSAGE_ID_EXTENSION_XPATH = 'acknowledgement/targetMessage/id/@extension'
      BODY_XPATH = 'env:Envelope/env:Body/idm:MCCI_IN000002UV01'
      CODE_XPATH = 'acknowledgement/typeCode/@code'

      # Creates a new parser instance.
      #
      # @param response [struct Faraday::Env] the Faraday response
      # @return [ProfileParser] an instance of this class
      def initialize(response)
        @original_body = locate_element(response.body, BODY_XPATH)
        @code = locate_element(@original_body, CODE_XPATH)

        if failed_or_invalid?
          PersonalInformationLog.create(
            error_class: 'MPI::Errors',
            data: {
              payload: response.body
            }
          )
        end
      end

      # Parse the response.
      #
      # @return [Array] Possible list of codes associated with request
      def parse
        raw_codes = locate_elements(@original_body, ACKNOWLEDGEMENT_DETAIL_CODE_XPATH)
        return [] unless raw_codes

        attributes = raw_codes.map(&:attributes)
        parse_ids(attributes)
      end

      def error_details(mpi_codes)
        error_details = {
          ack_detail_code: @code,
          id_extension: locate_element(@original_body, ACKNOWLEDGEMENT_TARGET_MESSAGE_ID_EXTENSION_XPATH),
          error_texts: []
        }
        error_text_nodes = locate_elements(@original_body, ACKNOWLEDGEMENT_DETAIL_TEXT_XPATH)
        if error_text_nodes.nil?
          error_details[:error_texts] = error_text_nodes
        else
          error_text_nodes.each do |node|
            error_details[:error_texts].append(node.text) unless error_details[:error_texts].include?(node.text)
          end
        end
        mpi_codes[:error_details] = error_details
        mpi_codes
      rescue
        mpi_codes
      end

      private

      def sanitize_uuid(full_identifier)
        full_identifier.split(IDENTIFIERS_SPLIT_TOKEN).first
      end

      # rubocop:disable Metrics/MethodLength
      def parse_ids(attributes)
        codes = { other: [] }
        attributes.each do |attribute|
          case attribute[:code]
          when /BRLS/
            codes[:birls_id] = sanitize_id(attribute[:code])
          when /CORP/
            codes[:participant_id] = sanitize_id(attribute[:code])
          when /200VIDM/
            codes[:idme_uuid] = sanitize_uuid(attribute[:code])
          when /200VLGN/
            codes[:logingov_uuid] = sanitize_uuid(attribute[:code])
          when /200DOD/
            codes[:edipi] = sanitize_edipi(attribute[:code])
          else
            if attribute[:displayName] == 'ICN'
              codes[:icn] = attribute[:code]
            else
              codes[:other].append(attribute)
            end
          end
        end
        codes.delete(:other) if codes[:other].empty?
        codes
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
