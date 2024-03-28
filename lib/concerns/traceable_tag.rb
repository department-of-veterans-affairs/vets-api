# frozen_string_literal: true

module TraceableTag
  extend ActiveSupport::Concern

  included do
    # A class_attribute is appropriate here as it allows overriding within subclasses (child controllers)
    # It is set via the service_tag method during controller declaration, and only read thereafter
    class_attribute :trace_service_tag # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  end

  class_methods do
    # Assigns a service tag to the controller class.
    # @param service_name [Symbol] the name of the service tag.
    # @return [Symbol] the set service tag.
    def service_tag(service_name)
      self.trace_service_tag = service_name
    end
  end
end
