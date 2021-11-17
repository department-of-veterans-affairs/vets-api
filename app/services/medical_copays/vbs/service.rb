# frozen_string_literal: true

module MedicalCopays
  module VBS
    ##
    # Service object for isolating dependencies in the {MedicalCopaysController}
    #
    # @!attribute request
    #   @return [MedicalCopays::Request]
    # @!attribute request_data
    #   @return [RequestData]
    # @!attribute response_data
    #   @return [ResponseData]
    class Service
      attr_reader :request, :request_data, :user

      ##
      # Builds a Service instance
      #
      # @param opts [Hash]
      # @return [Service] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @request = MedicalCopays::Request.build
        @user = opts[:user]
        @request_data = RequestData.build(user: user)
      end

      ##
      # Gets the user's medical copays by edipi and vista account numbers
      #
      # @return [Hash]
      #
      def get_copays
        raise InvalidVBSRequestError, request_data.errors unless request_data.valid?

        response = request.post("#{settings.base_path}/GetStatementsByEDIPIAndVistaAccountNumber", request_data.to_hash)
        zero_balance_statements = MedicalCopays::ZeroBalanceStatements.build(
          statements: response.body,
          facility_hash: user.vha_facility_hash
        )
        response.body.concat(zero_balance_statements.list)

        ResponseData.build(response: response).handle
      end

      def settings
        Settings.mcp.vbs
      end
    end
  end
end
