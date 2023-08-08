# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'
require_relative 'redis_client'
require_relative 'service_exception'

module Chip
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration Chip::Configuration
    STATSD_KEY_PREFIX = 'api.chip'

    attr_reader :tenant_name, :tenant_id, :username, :password, :redis_client

    ##
    # Builds a Service instance
    #
    # @param opts [Hash] options to create the object
    # @option opts [String] :tenant_name
    # @option opts [String] :tenant_id
    # @option opts [String] :username
    # @option opts [String] :password
    #
    # @return [Service] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts = {})
      @tenant_name = opts[:tenant_name]
      @tenant_id = opts[:tenant_id]
      @username = opts[:username]
      @password = opts[:password]
      validate_arguments!

      @redis_client = RedisClient.build(tenant_id)
      super()
    end

    def get_demographics(patient_dfn:, station_no:)
      perform(:get, '/actions/authenticated-demographics',
              { patientDfn: patient_dfn, stationNo: station_no },
              request_headers)
    end

    def update_demographics(patient_dfn:, station_no:, demographic_confirmations:)
      with_monitoring_and_error_handling do
        perform(:post, '/actions/authenticated-demographics',
                { patientDfn: patient_dfn, stationNo: station_no, demographicConfirmations: demographic_confirmations },
                request_headers)
      end
    end

    ##
    # Get the auth token from CHIP
    #
    # @return [Faraday::Response] response from CHIP token endpoint
    #
    def get_token
      with_monitoring do
        perform(:post, "/#{config.base_path}/token", {}, token_headers)
      end
    end

    ##
    # Post the check-in status to CHIP
    #
    # @return [Faraday::Response] response from CHIP authenticated-check-in endpoint
    #
    def post_patient_check_in(appointment_ien, patient_dfn, station_no)
      with_monitoring_and_error_handling do
        perform(:post, "/#{config.base_path}/actions/authenticated-check-in",
                { appointmentIen: appointment_ien, patientDfn: patient_dfn, stationNo: station_no },
                request_headers)
      end
    end

    private

    def request_headers
      default_headers.merge('Authorization' => "Bearer #{token}")
    end

    def token_headers
      claims_token = Base64.encode64("#{username}:#{password}")
      default_headers.merge('Authorization' => "Basic #{claims_token}")
    end

    def default_headers
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => config.api_gtwy_id
      }
    end

    def token
      @token ||= begin
        token = redis_client.get
        if token.present?
          token
        else
          resp = get_token

          Oj.load(resp.body)&.fetch('token').tap do |jwt_token|
            redis_client.save(token: jwt_token)
          end
        end
      end
    end

    def with_monitoring_and_error_handling(&)
      with_monitoring(2, &)
    rescue => e
      log_exception_to_sentry(e,
                              {
                                url: "#{config.url}/#{config.base_path}",
                                original_body: e.original_body,
                                original_status: e.original_status
                              },
                              { external_service: self.class.to_s.underscore, team: 'check-in' })
      raise e
    end

    def validate_arguments!
      raise ArgumentError, 'Invalid username' if username.blank?
      raise ArgumentError, 'Invalid password' if password.blank?
      raise ArgumentError, 'Invalid tenant parameters' if tenant_name.blank? || tenant_id.blank?
      raise ArgumentError, 'Tenant parameters do not exist' unless config.valid_tenant?(tenant_name:, tenant_id:)
    end
  end
end
