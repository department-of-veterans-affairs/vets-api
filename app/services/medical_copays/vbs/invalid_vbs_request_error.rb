# frozen_string_literal: true

module MedicalCopays
  module VBS
    ##
    # Custom error object for handling invalid VBS request params
    #
    # @!attribute errors
    #   @return [Array]
    class InvalidVBSRequestError < StandardError
      attr_accessor :errors

      def initialize(json_schema_errors)
        @errors = json_schema_errors
        message = json_schema_errors.pluck(:message)

        StatsD.increment('api.mcp.vbs.failure')

        super(message)
      end
    end
  end
end
