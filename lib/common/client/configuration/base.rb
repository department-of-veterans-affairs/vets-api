# frozen_string_literal: true

module Common
  module Client
    module Configuration
      ##
      # Base class for HTTP service configurations. This class should not be used directly.
      # Use {Common::Client::Configuration::REST} or {Common::Client::Configuration::SOAP} instead.
      #
      class Base
        include Singleton

        # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        # These attributes are inherited by subclasses so that
        # they can change their own value without impacting the parent class
        # @!group Class Attributes
        # @!attribute [rw]
        # timeout for opening the connection
        class_attribute :open_timeout

        # @!group Class Attributes
        # @!attribute [rw]
        # timeout for reading a response
        class_attribute :read_timeout

        # @!group Class Attributes
        # @!attribute [rw]
        # allowed requests types e.g. `%i[get put post delete].freeze`
        class_attribute :request_types

        # @!group Class Attributes
        # @!attribute [rw]
        # value for the User-Agent header
        class_attribute :user_agent

        # @!group Class Attributes
        # @!attribute [rw]
        # headers to include in all requests
        class_attribute :base_request_headers
        # rubocop:enable ThreadSafety/ClassAndModuleAttributes

        self.open_timeout = 15
        self.read_timeout = 15
        self.request_types = %i[get put post delete].freeze
        self.user_agent = 'Vets.gov Agent'
        self.base_request_headers = {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => user_agent
        }.freeze

        ##
        # The base path to use for all requests. Implemented by sub classes.
        #
        def base_path
          raise NotImplementedError, "Subclass #{self.class.name} of Configuration must implement base_path"
        end

        ##
        # The service name that shows up in breakers metrics and logs. Implemented by sub classes.
        #
        def service_name
          raise NotImplementedError, "Subclass #{self.class.name} of Configuration must implement service_name"
        end

        ##
        # Creates a custom service exception with the same namespace as the implementing class.
        #
        # @return Common::Exceptions::BackendServiceException execption with the class' namespace
        #
        def service_exception
          if current_module.const_defined?('ServiceException')
            current_module.const_get('ServiceException')
          else
            current_module.const_set('ServiceException', Class.new(Common::Exceptions::BackendServiceException))
          end
        end

        ##
        # Default request options, sets the read and open timeouts.
        #
        # @return Hash default request options.
        #
        def request_options
          {
            open_timeout:,
            timeout: read_timeout
          }
        end

        ##
        # Default request options, sets the read and open timeouts.
        #
        # @return Hash default request options.
        #
        def breakers_service
          return @service if defined?(@service)

          @service = create_new_breakers_service(breakers_matcher, breakers_exception_handler)
        end

        def breakers_matcher
          base_uri = URI.parse(base_path)
          proc do |breakers_service, request_env, request_service_name|
            # Match by service_name if available.
            request_service_name == breakers_service.name if request_service_name

            # Fall back to matching by request URL.
            request_env.url.host == base_uri.host && request_env.url.port == base_uri.port &&
              request_env.url.path =~ /^#{base_uri.path}/
          end
        end

        def breakers_exception_handler
          proc do |exception|
            case exception
            when Common::Exceptions::BackendServiceException
              (500..599).cover?(exception.response_values[:status])
            when Common::Client::Errors::HTTPError
              (500..599).cover?(exception.status)
            when Faraday::ServerError
              (500..599).cover?(exception.response&.[](:status))
            else
              false
            end
          end
        end

        def create_new_breakers_service(matcher, exception_handler)
          Rails.logger.debug('Creating new service for', service_name)
          Breakers::Service.new(
            name: service_name,
            request_matcher: matcher,
            error_threshold: breakers_error_threshold,
            exception_handler:
          )
        end

        # The percentage of errors over which an outage will be reported as part of breakers gem
        #
        # @return [Integer] corresponding to percentage
        def breakers_error_threshold
          50
        end

        private

        # deconstantize fetches "AA::BB::" from AA::BB::ClassName, and constantize returns that as a constant.
        def current_module
          self.class.name.deconstantize.constantize
        end
      end
    end
  end
end
