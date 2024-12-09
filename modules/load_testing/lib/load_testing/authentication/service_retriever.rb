module LoadTesting
  module Authentication
    class ServiceRetriever
      class << self
        def register_service(type, service_class)
          @services ||= {}
          @services[type.to_s] = service_class
        end

        def for_type(type)
          @services ||= {}
          @services[type.to_s] || raise(ArgumentError, "Unknown authentication type: #{type}")
        end
      end
    end
  end
end 