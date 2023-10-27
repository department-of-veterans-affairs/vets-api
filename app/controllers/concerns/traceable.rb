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
  end

  # Sets trace tags for the current action. If no service tag is set, do nothing.
  # @note After all current controllers implement service tagging, this could raise an error instead.
  def set_trace_tags
    raise('SERVICE_TAG constant is not set') unless self.class.const_defined?(:SERVICE_TAG)

    # Not warning for now, re-introduce once we are at 100% of controllers tagged
    # return Rails.logger.warn('Service tag missing', class: self.class.name) if service.blank?
    Datadog::Tracing.active_span&.service = self.class::SERVICE_TAG
  rescue => e
    Rails.logger.error('Error setting service tag', class: self.class.name, message: e.message)
  end
end
