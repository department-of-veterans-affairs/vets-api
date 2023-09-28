# frozen_string_literal: true

require 'tracers/datadog_adapter'

# Provides functionality to controllers for tagging them with specific services.
# This tagging allows monitoring and tracing systems (like Datadog) to identify and group
# the activities of specific controllers based on the service tags they are associated with.
#
# @example Setting a service tag for a controller
#   class MyController < ApplicationController
#     include Traceable
#     service_tag :my_service
#   end
#
# @note The actual interaction with the monitoring service is abstracted away
#   and is handled by {Tracers::DatadogAdapter}. This module mainly focuses on
#   providing the mechanism to set and validate the service tags for controllers.
#
# @see Tracers::DatadogAdapter for details on how tags are set for external services.
module Traceable
  extend ActiveSupport::Concern

  # @!attribute [r] TRACE_ADAPTER
  #   @return [Tracers::DatadogAdapter] Adapter for interacting with external tracing services.
  TRACE_ADAPTER = Tracers::DatadogAdapter

  # @!attribute [r] SERVICES
  #   List of valid services. These define possible service tags that a controller can have.
  #   TODO: load this from a config file.
  #   @return [Array<Symbol>]
  SERVICES = %i[evss_letters evss_gi_bill_status prescriptions secure_messaging].freeze

  included do
    before_action :set_trace_tags
  end

  module ClassMethods
    # @!attribute [rw] trace_service_tag
    #   @return [Symbol] the service tag for a specific controller.
    attr_accessor :trace_service_tag

    # Assigns a service tag to the controller class.
    # @param service_name [Symbol] the name of the service tag.
    # @raise [RuntimeError] if the provided service tag is not valid.
    # @return [Symbol] the set service tag.
    def service_tag(service_name)
      raise "Invalid service tag in #{self.class.name}: #{service_name}" unless SERVICES.include?(service_name)

      self.trace_service_tag = service_name
    end
  end

  # Sets trace tags for the current action. If no service tag is set, logs a warning.
  # If an error occurs while setting the trace tag, logs an error.
  # @note After all current controllers implement service tagging, this could raise an error instead.
  def set_trace_tags
    service = self.class.trace_service_tag

    return Rails.logger.warn('Service tag missing', class: self.class.name) if service.blank?

    TRACE_ADAPTER.set_service_tag(service)
  rescue => e
    Rails.logger.error('Error setting service tag', class: self.class.name, message: e.message)
  end
end
