# frozen_string_literal: true

module AppealsApi
  module HigherLevelReviews
    class V1Validator
      INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_NUMBER_MAX_LENGTH = 100

      def initialize(request_body, request_headers)
        @request_body = request_body
        @request_headers = request_headers
      end

      def validate!
        return false, length_error if icr_name_phone_too_long?

        [true, nil]
      end

      private

      attr_accessor :request_body, :request_headers

      def length_error
        "
        Informal conference rep will not fit on form
        #{INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_NUMBER_MAX_LENGTH} char limit:
        #{informal_conference_rep_name} #{informal_conference_rep_phone}
        "
      end

      def icr_name_phone_too_long?
        "#{informal_conference_rep_name} #{informal_conference_rep_phone}".length >
          INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_NUMBER_MAX_LENGTH
      end

      def informal_conference_rep
        request_body.dig('data', 'attributes', 'informalConferenceRep')
      end

      def informal_conference_rep_name
        informal_conference_rep&.dig('name')
      end

      def informal_conference_rep_phone
        AppealsApi::HigherLevelReview::Phone.new(informal_conference_rep&.dig('phone'))
      end
    end
  end
end
