# frozen_string_literal: true

require 'map/security_token/service'

module Map
  ##
  # A class to provide functionality related to MAP appointments service.
  #
  class Service
    attr_reader :patient_identifier, :query_params, :redis_client

    ##
    # Builds a Service instance
    #
    # @param opts [Hash] options to create the object
    #
    # @return [Service] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts = {})
      @patient_identifier = opts[:patient_identifier]
      @query_params = opts[:query_params]
      @redis_client = RedisClient.build
    end

    # Get the auth token. If the token does not already exist in Redis, a call is made to Map token
    # endpoint to retrieve it.
    #
    # @return [String] token
    def token
      @token ||= fetch_or_generate_token
    end

    def fetch_or_generate_token
      token = redis_client.token(patient_identifier:)

      return token if token.present?

      current_time = Time.zone.now
      token_response = MAP::SecurityToken::Service.new.token(application: :check_in, icn: patient_identifier)

      redis_client.save_token(
        patient_identifier:,
        token: token_response[:access_token],
        expires_in: token_response[:expiration] - current_time
      )

      token_response[:access_token]
    end

    def get_appointments(token:, patient_identifier:, time_period:)
      if token.present?
        resp = client.get_appointments(token:, patient_identifier:, time_period:)

        case resp[:status]
        when 200
          serialized_data = VAOS::V2::AppointmentsSerializer.new(resp[:data]).serializable_hash
          response_data = { data: serialized_data, status: :ok }
        when 400
          error_data = {
            message: resp[:message] || 'Bad Request',
            detail: resp[:detail] || 'Bad request data entered'
          }
          response_data = { error: error_data, status: :bad_request }
        when 500
          error_data = if resp[:message].is_a?(String) && resp[:detail].is_a?(String)
                         resp[:error_data]
                       else
                         {
                           message: 'No error code found',
                           detail: 'Unknown error occurred'
                         }
                       end
          Rails.logger.error "500 error get_appointments - Message: #{error_data[:message]},
            Detail: #{error_data[:detail]}"
          response_data = { error: error_data, status: :internal_server_error }
        else
          response_data = { error: 'Unknown error', status: :internal_server_error }
        end
      else
        response_data = { message: 'Unauthorized', status: :unauthorized }
      end

      response_data
    end
  end
end
