# frozen_string_literal: true

module MedicalCopays
  module VBS
    ##
    # Object for handling VBS responses
    #
    # @!attribute body
    #   @return [String]
    # @!attribute status
    #   @return [Integer]
    class ResponseData
      attr_reader :body, :status

      ##
      # Builds a ResponseData instance
      #
      # @param opts [Hash]
      # @return [ResponseData] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @body = opts[:response].body || []
        @status = opts[:response].status
      end

      ##
      # The response hash to be returned to the {MedicalCopaysController}
      #
      # @return [Hash]
      #
      def handle
        case status
        when 200
          { data: transformed_body, status: status }
        when 400
          { data: { message: 'Bad request' }, status: status }
        when 401
          { data: { message: 'Unauthorized' }, status: status }
        when 403
          { data: { message: 'Forbidden' }, status: status }
        when 404
          { data: { message: 'Resource not found' }, status: status }
        else
          { data: { message: 'Something went wrong' }, status: status }
        end
      end

      ##
      # Camelize and lowercase all keys in the response body
      #
      # @return [Array]
      #
      def transformed_body
        body.each do |copay|
          copay.deep_transform_keys! { |key| key.camelize(:lower) }
        end
      end
    end
  end
end
