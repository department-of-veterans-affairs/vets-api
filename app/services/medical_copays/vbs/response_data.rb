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

      STATSD_KEY_PREFIX = 'api.mcp.vbs'

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
          StatsD.increment("#{STATSD_KEY_PREFIX}.success")
          { data: transformed_body, status: status }
        when 400
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Bad request' }, status: status }
        when 401
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Unauthorized' }, status: status }
        when 403
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Forbidden' }, status: status }
        when 404
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Resource not found' }, status: status }
        else
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Something went wrong' }, status: status }
        end
      end

      ##
      # Camelize and lowercase all keys in the response body
      #
      # @return [Array]
      #
      def transformed_body
        last_six_months_statements.each do |copay|
          copay.deep_transform_keys! { |key| key.camelize(:lower) }
        end
      end

      private

      ##
      # Filter statements by only the last six months
      #
      # @return [Array]
      #
      def last_six_months_statements
        cutoff_date = Time.zone.today - 6.months
        body.select do |statement|
          statement_date(statement) > cutoff_date
        end
      end

      ##
      # The Date object of the statement date string
      #
      # @return [Date]
      #
      def statement_date(statement)
        Time.zone.strptime(statement['pS_STATEMENT_DATE'], '%m%d%y')
      end
    end
  end
end
