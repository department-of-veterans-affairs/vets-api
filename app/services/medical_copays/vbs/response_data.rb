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
          { data: transformed_body, status: }
        when 400
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Bad request' }, status: }
        when 401
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Unauthorized' }, status: }
        when 403
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Forbidden' }, status: }
        when 404
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Resource not found' }, status: }
        else
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
          { data: { message: 'Something went wrong' }, status: }
        end
      end

      ##
      # Camelize and lowercase all keys in the response body
      #
      # @return [Array]
      #
      def transformed_body
        statements = Flipper.enabled?(:medical_copays_six_mo_window) ? last_six_months_statements : body
        statements.each do |copay|
          calculate_cerner_account_number(copay)
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
      # Custom cerner account number to match PDF
      #
      # @return [Hash]
      #
      def calculate_cerner_account_number(statement)
        return unless account_number_present?(statement['pH_CERNER_ACCOUNT_NUMBER'])

        facility_id = statement['pS_FACILITY_NUM']
        patient_id = statement['pH_CERNER_PATIENT_ID']
        offset = 15 - (facility_id + patient_id).length
        padding = '0' * offset if offset >= 0

        statement['pH_CERNER_ACCOUNT_NUMBER'] = "#{facility_id}1#{padding}#{patient_id}"
      end

      ##
      # The Date object of the statement date string
      #
      # @return [Date]
      #
      def statement_date(statement)
        Time.zone.strptime(statement['pS_STATEMENT_DATE'], '%m%d%Y')
      end

      def account_number_present?(n)
        n.present? && n != 0 && n != '0'
      end
    end
  end
end
