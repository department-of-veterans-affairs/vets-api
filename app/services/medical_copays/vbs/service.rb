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
      include RedisCaching
      class StatementNotFound < StandardError
      end

      attr_reader :request, :request_data, :user

      STATSD_KEY_PREFIX = 'api.mcp.vbs'

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
        @request_data = RequestData.build(user:) unless user.nil?
      end

      ##
      # Gets the user's medical copays by edipi and vista account numbers
      #
      # @return [Hash]
      #
      def get_copays
        raise InvalidVBSRequestError, request_data.errors unless request_data.valid?

        if Flipper.enabled?(:debts_copay_logging)
          Rails.logger.info("MedicalCopays::VBS::Service#get_copay_response request data: #{@user.uuid}")
        end

        response = get_cached_copay_response

        # enable zero balance debt feature if flip is on
        if Flipper.enabled?(:medical_copays_zero_debt)
          zero_balance_statements = MedicalCopays::ZeroBalanceStatements.build(
            statements: response.body,
            facility_hash: user.vha_facility_hash
          )
          response.body.concat(zero_balance_statements.list)
        end

        ResponseData.build(response:).handle
      end

      def get_cached_copay_response
        StatsD.increment("#{STATSD_KEY_PREFIX}.init_cached_copays.fired")

        cached_response = get_user_cached_response
        if cached_response
          StatsD.increment("#{STATSD_KEY_PREFIX}.init_cached_copays.cached_response_returned")
          return cached_response
        end

        response = request.post(
          "#{settings.base_path}/GetStatementsByEDIPIAndVistaAccountNumber", request_data.to_hash
        )
        binding.pry
        response_body = response.body

        if response_body.is_a?(Array) && response_body.empty?
          StatsD.increment("#{STATSD_KEY_PREFIX}.init_cached_copays.empty_response_cached")
          Rails.cache.write("vbs_copays_data_#{user.uuid}", response, expires_in: self.class.time_until_5am_utc)
        end

        response
      end

      ##
      # Get's the users' medical copay by statement id from list
      #
      # @param id [UUID] - uuid of the statement
      # @return [Hash] - JSON data of statement and status
      #
      def get_copay_by_id(id)
        all_statements = get_copays

        # Return hash with error information if bad response
        return all_statements unless all_statements[:status] == 200

        statement = get_copays[:data].find { |copay| copay['id'] == id }

        raise StatementNotFound if statement.nil?

        { data: statement, status: 200 }
      end

      ##
      # Gets the PDF medical copay statment by statment_id
      #
      # @return [Hash]
      #
      def get_pdf_statement_by_id(statement_id)
        StatsD.increment("#{STATSD_KEY_PREFIX}.pdf.total")
        response = request.get("#{settings.base_path}/GetPDFStatementById/#{statement_id}")

        Base64.decode64(response.body['statement'])
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.pdf.failure")
        raise e
      end

      def get_user_cached_response
        cache_key = "vbs_copays_data_#{user.uuid}"
        Rails.cache.read(cache_key)
      end

      def send_statement_notifications(_statements_json_byte)
        # Commenting for now since we are causingissues in production
        # when the child job runs: "NewStatementNotificationJob"
        # CopayNotifications::ParseNewStatementsJob.perform_async(statements_json_byte)
        true
      end

      def settings
        Flipper.enabled?(:medical_copays_api_key_change) ? Settings.mcp.vbs_v2 : Settings.mcp.vbs
      end
    end
  end
end
