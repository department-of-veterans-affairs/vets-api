# frozen_string_literal: true
require_relative 'base'
require_relative 'profile_parser'

module MVI
  module Responses
    # Parses the response for the find candidate endpoint (prpa_in201306_uv02).
    #
    # = Usage
    # The original response is a complex Hash of the xml returned by MVI.
    # See specs/support/mvi/savon_response_body.json for an example of the hierarchy
    #
    # Example:
    #  response = MVI::Responses::FindCandidate.new(mvi_response)
    #
    class FindProfileResponse < Base
      mvi_endpoint :PRPA_IN201306UV02

      attr_reader :status, :profile

      ACKNOWLEDGEMENT_DETAIL_XPATH = 'acknowledgement/acknowledgementDetail/text'
      MULTIPLE_MATCHES_FOUND = 'Multiple Matches Found'

      RESPONSE_STATUS = {
        ok: 'OK',
        not_found: 'NOT_FOUND',
        server_error: 'SERVER_ERROR'
      }.freeze

      def initialize(response)
        super(response)
        raise MVI::Errors::InvalidRequestError if invalid?
        raise MVI::Errors::RequestFailureError if failure?
        @profile = ProfileParser.new(@original_body).parse
        @status = set_status
      end

      def ok?
        @status == RESPONSE_STATUS[:ok]
      end

      def not_found?
        @status == RESPONSE_STATUS[:not_found]
      end

      def server_error?
        @status == RESPONSE_STATUS[:server_error]
      end

      private

      def set_status
        case
        when multiple_match? || @profile.nil?
          RESPONSE_STATUS[:not_found]
        when invalid?
          RESPONSE_STATUS[:server_error]
        when failure?
          RESPONSE_STATUS[:server_error]
        else
          RESPONSE_STATUS[:ok]
        end
      end

      def multiple_match?
        acknowledgement_detail = locate_element(@original_body, ACKNOWLEDGEMENT_DETAIL_XPATH)
        return false unless acknowledgement_detail
        acknowledgement_detail.nodes.first == MULTIPLE_MATCHES_FOUND
      end
    end
  end
end
