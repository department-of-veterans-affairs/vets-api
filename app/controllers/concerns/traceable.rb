# frozen_string_literal: true

# Provides functionality to controllers for tagging them with specific services.
# This tagging allows monitoring and tracing systems (like Datadog) to identify and group
# the activities of specific controllers based on the service tags they are associated with.
#
# @example Setting a service tag for a controller
#   class MyController < ApplicationController
#     include Traceable
#     service_tag :my_service
#   end
module Traceable
  extend ActiveSupport::Concern

  included do
    before_action :set_trace_tags

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

  # Sets trace tags for the current action. If no service tag is set, do nothing.
  # @note After all current controllers implement service tagging, this could raise an error instead.
  def set_trace_tags
    service = self.class.trace_service_tag

    # Not warning for now, re-introduce once we are at 100% of controllers tagged
    # return Rails.logger.warn('Service tag missing', class: self.class.name) if service.blank?

    Datadog::Tracing.active_span&.service = service if service.present?
  rescue => e
    Rails.logger.error('Error setting service tag', class: self.class.name, message: e.message)
  end

  # Wraps controller methods with the controller class name as "origin".
  def tag_with_controller_name(&)
    return yield if self.class.name.blank?

    SemanticLogger.named_tagged(origin: self.class.name.underscore, &)
  end
end
