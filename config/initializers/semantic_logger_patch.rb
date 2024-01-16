# frozen_string_literal: true
require 'rails_semantic_logger'
require 'active_support/log_subscriber'

module ActiveSupport
  class LogSubscriber
    # @override SemanticLogger @override Rails 7.1
    def silenced?(event)
      logger.nil? || @event_levels[event]&.call(logger)
    end
  end
end
