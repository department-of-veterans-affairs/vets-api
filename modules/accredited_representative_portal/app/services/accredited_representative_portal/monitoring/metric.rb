# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Monitoring
    # Datadog Metrics Structure
    #
    # This module provides a multi-dimensional approach to metric tracking using 2 core metrics:
    # - request: Tracks occurrences of operations/events, including errors
    # - duration: Tracks timing/performance metrics
    #
    # Each metric can be analyzed across 4 dimensions using tags:
    # - category: What system/area it belongs to (auth, poa, bgs, etc.)
    # - operation: What action was performed (create, update, search, etc.)
    # - source: Where it originated (api, frontend, background, etc.)
    # - level: Severity level (info, warn, error, critical)
    # - error: Type of failure (only for errors)
    #
    # Example usages:
    #
    # Basic request tracking:
    #   statsd.increment(Metrics::REQUEST, tags: [
    #     TAGS::Category::POA,
    #     TAGS::Operation::CREATE,
    #     TAGS::Source::API
    #   ])
    #
    # Performance tracking:
    #   statsd.timing(Metrics::DURATION, duration, tags: [
    #     TAGS::Category::POA,
    #     TAGS::Operation::SEARCH
    #   ])
    #
    # Error tracking:
    #   statsd.increment(Metrics::REQUEST, tags: [
    #     TAGS::Category::BGS,
    #     TAGS::Operation::VALIDATE,
    #     TAGS::Level::ERROR,
    #     TAGS::Error::TIMEOUT
    #   ])
    #
    # This structure allows for powerful Datadog queries like:
    # - Success rate by operation: 'arp.api.request{category:poa} by {operation}'
    # - Error patterns: 'arp.api.request{level:error} by {error}'
    # - Performance by source: 'arp.api.duration{*} by {source}'
    #
    # Each dimension can be combined in queries for deep analysis:
    # - Frontend validation errors: '{source:frontend,error:validation}'
    # - BGS timeout rate: '{category:bgs,error:timeout}'
    # - POA creation performance: '{category:poa,operation:create}'
    module Metric
      BASE = 'arp.api'
      ALL = [
        POA = "#{BASE}.poa".freeze
      ].freeze
    end
  end
end
