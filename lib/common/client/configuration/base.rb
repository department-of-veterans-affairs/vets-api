# frozen_string_literal: true

module Common
  module Client
    module Configuration
      class Base
        include Singleton

        class_attribute :open_timeout
        class_attribute :read_timeout
        class_attribute :request_types
        class_attribute :user_agent
        class_attribute :base_request_headers

        self.open_timeout = 15
        self.read_timeout = 15
        self.request_types = %i[get put post delete].freeze
        self.user_agent = 'Vets.gov Agent'
        self.base_request_headers = {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => user_agent
        }.freeze

        def base_path
          raise NotImplementedError, "Subclass #{self.class.name} of Configuration must implement base_path"
        end

        def service_name
          raise NotImplementedError, "Subclass #{self.class.name} of Configuration must implement service_name"
        end

        def service_exception
          if current_module.const_defined?('ServiceException')
            current_module.const_get('ServiceException')
          else
            current_module.const_set('ServiceException', Class.new(Common::Exceptions::BackendServiceException))
          end
        end

        def request_options
          {
            open_timeout: open_timeout,
            timeout: read_timeout
          }
        end

        def breakers_service
          return @service if defined?(@service)
          base_uri = URI.parse(base_path)
          matcher = proc do |request_env|
            request_env.url.host == base_uri.host && request_env.url.port == base_uri.port &&
              request_env.url.path =~ /^#{base_uri.path}/
          end

          exception_handler = proc do |exception|
            if exception.is_a?(Common::Exceptions::BackendServiceException)
              (500..599).cover?(exception.response_values[:status])
            elsif exception.is_a?(Common::Client::Errors::HTTPError)
              (500..599).cover?(exception.status)
            else
              false
            end
          end

          @service = Breakers::Service.new(
            name: service_name,
            request_matcher: matcher,
            exception_handler: exception_handler
          )
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
