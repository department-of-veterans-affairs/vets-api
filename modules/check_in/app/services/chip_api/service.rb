# frozen_string_literal: true

require 'forwardable'

module ChipApi
  ##
  # A service object for isolating dependencies from the PatientCheckInsController and
  # the Chip API. An object responsible for making requests from the Chip API, Caching,
  # Instrumenting, and performing any other tasks related to the Chip API.
  #
  # @!attribute request
  #   @return [ChipApi::Request]
  # @!attribute session
  #   @return [ChipApi::Session]
  # @!attribute check_in
  #   @return [CheckIn]
  # @!method client_error
  #   @return (see CheckIn#client_error)
  # @!method uuid
  #   @return (see CheckIn#uuid)
  # @!method session
  #   @return (see CheckIn#session)
  #
  class Service
    attr_reader :check_in, :request, :session

    extend Forwardable

    def_delegators :check_in, :client_error, :uuid, :valid?

    ##
    # Builds a Service instance
    #
    # @param check_in [CheckIn]
    # @return [ChipApi::Service] an instance of this class
    #
    def self.build(check_in)
      new(check_in)
    end

    def initialize(check_in)
      @check_in = check_in
      @request = Request.build
      @session = Session.build
    end

    ##
    # Gets the resource by its unique ID
    #
    # @return [Hash]
    #
    def get_check_in
      return handle_response(client_error) unless valid?

      token = session.retrieve
      resp = request.get(path: "/#{base_path}/appointments/#{uuid}", access_token: token)

      handle_response(resp)
    end

    ##
    # Create a resource for the logged in user.
    #
    # @return [Hash]
    #
    def create_check_in
      return handle_response(client_error) unless valid?

      token = session.retrieve
      resp = request.post(path: "/#{base_path}/actions/check-in/#{uuid}", access_token: token)

      handle_response(resp)
    end

    ##
    # Helper method for returning the Chip URL base path
    # from our environment configuration file
    #
    # @return [String]
    #
    def base_path
      Settings.check_in.chip_api.base_path
    end

    ##
    # Handle and format the response for the UI
    #
    # @param resp [Faraday::Response]
    # @return [Hash]
    #
    def handle_response(resp)
      body = resp&.body
      value = begin
        Oj.load(body)
      rescue
        body
      end
      status = resp&.status

      case status
      when 200, 400
        { data: value, status: status }
      when 401
        { data: { error: true, message: 'Unauthorized' }, status: status }
      when 404
        { data: { error: true, message: 'We could not find that UUID' }, status: status }
      when 403
        { data: { error: true, message: 'Forbidden' }, status: status }
      else
        { data: { error: true, message: 'Something went wrong' }, status: status }
      end
    end
  end
end
