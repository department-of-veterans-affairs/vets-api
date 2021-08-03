# frozen_string_literal: true

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
  #
  class Service
    attr_reader :request, :session

    ##
    # Builds a Service instance
    #
    # @return [ChipApi::Service] an instance of this class
    #
    def self.build
      new
    end

    def initialize
      @request = Request.build
      @session = Session.build
    end

    ##
    # Gets the resource by its unique ID
    #
    # @param id [String] a unique string value
    # @return [Hash]
    #
    def get_check_in(id)
      token = session.retrieve
      resp = request.get(path: "/dev/appointments/#{id}", access_token: token)

      handle_response(resp)
    end

    ##
    # Create a resource for the logged in user.
    #
    # @param data [Hash] data submitted by the user.
    # @return [Hash]
    #
    def create_check_in(id)
      token = session.retrieve
      resp = request.post(path: "/dev/actions/check-in/#{id}", access_token: token)

      handle_response(resp)
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
      when 200
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
