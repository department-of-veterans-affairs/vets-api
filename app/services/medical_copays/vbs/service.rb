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
      attr_reader :request, :request_data

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
        @request_data = RequestData.build(user: opts[:user])
      end

      ##
      # Gets the user's medical copays by edipi and vista account numbers
      #
      # @return [Hash]
      #
      def get_copays
        raise InvalidVBSRequestError, request_data.errors unless request_data.valid?

        response = request.post('/Prod/GetStatementsByEDIPIAndVistaAccountNumber', request_data.to_hash)

        ResponseData.build(response: response).handle
      end
    end
  end
end
