# frozen_string_literal: true

# TODO remove Sidekiq::Instrument::Worker
class SidekiqStatsJob < Sidekiq::Instrument::Worker
  METRIC_NAMES = %w[
    processed
    failed
    scheduled_size
  ].freeze

  sidekiq_options queue: 'critical'
end
