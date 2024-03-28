# frozen_string_literal: true

require 'concerns/traceable_tag'

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
  include TraceableTag

  included do
    before_action :set_trace_tags
  end

  # Sets trace tags for the current action. If no service tag is set, do nothing.
  # @note After all current controllers implement service tagging, this could raise an error instead.
  def set_trace_tags
    service = self.class.trace_service_tag
    Datadog::Tracing.active_span&.service = service if service.present?
  rescue => e
    Rails.logger.error('Error setting service tag', class: self.class.name, message: e.message)
  end
end
