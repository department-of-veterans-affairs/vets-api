# frozen_string_literal: true

require 'forwardable'

module TravelClaim
  class TravelPayClient < Common::Client::Base
    configuration TravelClaim::Configuration
    extend Forwardable
    include Common::Client::Concerns::Monitoring

    EXPENSE_DESCRIPTION = 'mileage'
    TRIP_TYPE = 'RoundTrip'
    GRANT_TYPE = 'client_credentials'
    CLIENT_TYPE = '1'
    CLAIM_NAME = 'Travel Reimbursement'
    CLAIMANT_TYPE = 'Veteran'
    STATSD_KEY_PREFIX = 'api.check_in.travel_claim'

    def_delegators :settings,
                   :auth_url, :tenant_id, :travel_pay_client_id, :travel_pay_client_secret,
                   :scope, :claims_url_v2, :subscription_key, :e_subscription_key, :s_subscription_key,
                   :client_number, :travel_pay_resource, :client_secret

    def initialize(uuid:, check_in_uuid:, appointment_date_time:, icn:, station_number:)
      @uuid = uuid
      @check_in_uuid = check_in_uuid
      @appointment_date_time = appointment_date_time
      @icn = icn
      @station_number = station_number
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @redis = TravelClaim::RedisClient.build
      @correlation_id = SecureRandom.uuid
      @current_veis_token = nil
      @current_btsss_token = nil
      validate_required_arguments
      super()
    end

    # ---------- Public API (with op context) ----------

    def find_or_add_appointment!
      with_btsss_op('appointments#find_or_add') do |h|
        body = { appointmentDateTime: @appointment_date_time, facilityStationNumber: @station_number }
        perform(:post, 'api/v3/appointments/find-or-add', body, h).body
      end.dig('data', 0, 'id')
    end

    def create_claim!(appointment_id:)
      with_btsss_op('claims#create') do |h|
        body = { appointmentId: appointment_id, claimName: CLAIM_NAME, claimantType: CLAIMANT_TYPE }
        perform(:post, 'api/v3/claims', body, h).body
      end.dig('data', 'claimId')
    end

    def add_mileage_expense!(claim_id:, date_incurred:)
      with_btsss_op('expenses#mileage') do |h|
        body = { claimId: claim_id, dateIncurred: date_incurred, description: EXPENSE_DESCRIPTION, tripType: TRIP_TYPE }
        perform(:post, 'api/v3/expenses/mileage', body, h).body
      end
    end

    def submit_claim!(claim_id:)
      with_btsss_op('claims#submit') do |h|
        request(:patch, "api/v3/claims/#{claim_id}/submit", {}, h).body
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
    end

    ##
    # Sends a request to get a claim by ID.
    #
    # @param claim_id [String] Claim ID
    # @return [Faraday::Response] HTTP response containing claim data
    #
    def get_claim(claim_id:)
      with_btsss_op('claims#get') do |h|
        perform(:get, "api/v3/claims/#{claim_id}", nil, h)
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
    end

    # ---------- Auth wrapper ----------

    def with_auth
      @auth_retry_attempted = false
      bootstrap_tokens!
      yield(base_headers)
    rescue service_exception_class, Common::Exceptions::BackendServiceException => e
      handle_auth_exception(e) do
        bootstrap_tokens!
        yield(base_headers)
      end
    rescue Common::Exceptions::BackendServiceException => e
      handle_backend_service_exception(e)
    end

    # ---------- Token lifecycle ----------

    def bootstrap_tokens!
      ensure_tokens!
      raise_auth_bootstrap! if @current_veis_token.blank? || @current_btsss_token.blank?
    end

    def ensure_tokens!
      return if @current_veis_token && @current_btsss_token

      @current_veis_token = @redis.token || request_veis_token
      cache_veis!
      fetch_btsss_token!
    end

    def refresh_tokens!
      purge_tokens!
      ensure_tokens!
    end

    # ---------- Raw token calls ----------

    def request_veis_token
      with_monitoring do
        body = veis_form_body
        perform(:post, "#{tenant_id}/oauth2/token", body, form_headers, { server_url: auth_url }).body['access_token']
      end
    end

    def fetch_btsss_token!
      with_monitoring do
        body = { secret: travel_pay_client_secret, icn: @icn }
        @current_btsss_token = perform(:post, 'api/v4/auth/system-access-token', body, system_headers)
                               .body.dig('data', 'accessToken')
      end
    end

    # ---------- perform override (patch + server_url) ----------

    def perform(method, path, params, headers = nil, options = nil)
      srv = options&.delete(:server_url)
      return request(:patch, path, params || {}, headers || {}, options || {}) if method == :patch

      if srv
        request_config = build_request_config(headers, options)
        return perform_with_server(srv, method, path, params, request_config)
      end

      super
    end

    def perform_with_server(srv, method, path, params, request_config = {})
      headers = request_config.delete(:headers) || {}
      options = request_config
      conn = config.connection(server_url: srv)
      conn.send(method.to_sym, path, params || {}) do |req|
        req.headers.update(headers)
        options.each { |k, v| req.options.send("#{k}=", v) }
      end.env
    end

    # ---------- Private helpers ----------

    private

    def build_request_config(headers, options)
      config = options || {}
      config[:headers] = headers || {}
      config
    end

    def with_btsss_op(op, &)
      @current_operation = op
      with_auth(&)
    rescue service_exception_class => e
      transform_service_exception(e)
    ensure
      @current_operation = nil
    end

    def transform_service_exception(e)
      code = classify_error(e)
      safe_log_api_error(e.original_status, code, @current_operation)
      vals = (e.respond_to?(:response_values) ? e.response_values.dup : {}) || {}
      vals[:detail] ||= safe_extract_detail(e.original_body)
      key = e.respond_to?(:key) ? e.key : 'VA900'
      raise Common::Exceptions::BackendServiceException.new(key, vals, e.original_status, nil)
    end

    def classify_error(e)
      s = e.original_status.to_i
      return 'unauthorized' if s == 401
      return 'rate_limited' if s == 429
      return 'duplicate_claim' if body_includes?(e.original_body, 'already been created')
      return 'validation' if s == 400
      return 'conflict' if s == 409

      'server_error'
    end

    def body_includes?(body, needle)
      return false unless body && needle

      str = body.is_a?(String) ? body : body.to_json
      str.downcase.include?(needle)
    rescue
      false
    end

    def handle_auth_exception(error)
      if (error.respond_to?(:original_status) ? error.original_status : nil) == 401 && !@auth_retry_attempted
        @auth_retry_attempted = true
        purge_tokens!
        yield
      else
        raise
      end
    end

    def purge_tokens!
      @current_veis_token = nil
      @current_btsss_token = nil
      @redis.save_token(token: nil)
    end

    def raise_auth_bootstrap!
      raise Common::Exceptions::BackendServiceException.new('VA901', { detail: 'Auth bootstrap failed' }, 401, nil)
    end

    def base_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@current_veis_token}",
        'BTSSS-Access-Token' => @current_btsss_token,
        'X-Correlation-ID' => @correlation_id
      }.merge(subscription_key_headers)
    end

    def subscription_key_headers
      return { 'Ocp-Apim-Subscription-Key' => subscription_key } unless Settings.vsp_environment == 'production'

      { 'Ocp-Apim-Subscription-Key-E' => e_subscription_key, 'Ocp-Apim-Subscription-Key-S' => s_subscription_key }
    end

    def veis_form_body
      URI.encode_www_form({
                            client_id: travel_pay_client_id, client_secret:, client_type: CLIENT_TYPE,
                            scope:, grant_type: GRANT_TYPE, resource: travel_pay_resource
                          })
    end

    def form_headers
      { 'Content-Type' => 'application/x-www-form-urlencoded' }
    end

    def system_headers
      {
        'Content-Type' => 'application/json',
        'X-Correlation-ID' => @correlation_id,
        'BTSSS-API-Client-Number' => client_number.to_s,
        'Authorization' => "Bearer #{@current_veis_token}"
      }.merge(subscription_key_headers)
    end

    def cache_veis!
      @redis.save_token(token: @current_veis_token) if @current_veis_token.present?
    end

    def safe_extract_detail(body)
      return nil unless body

      parsed = body.is_a?(String) ? JSON.parse(body) : body
      msg = parsed.is_a?(Hash) ? parsed['message'] : nil
      msg if msg&.match?(/\A[a-z0-9 \-_,.:'"]{1,200}\z/i)
    rescue JSON::ParserError
      nil
    end

    def safe_log_api_error(status, code, op)
      Rails.logger.error('TravelPayClient API error', {
                           correlation_id: @correlation_id, uuid_hash: @uuid, status:, code:, operation: op
                         })
    end

    def service_exception_class
      config.service_exception
    end

    attr_reader :settings

    def validate_required_arguments
      raise ArgumentError, 'UUID cannot be blank' if @uuid.blank?
      raise ArgumentError, 'Check-in UUID cannot be blank' if @check_in_uuid.blank?
      raise ArgumentError, 'appointment date time cannot be blank' if @appointment_date_time.blank?
      raise ArgumentError, 'ICN cannot be blank' if @icn.blank?
      raise ArgumentError, 'station number cannot be blank' if @station_number.blank?
    end
  end
end
