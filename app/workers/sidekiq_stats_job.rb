# frozen_string_literal: true
class SidekiqStatsJob < Sidekiq::Instrument::Worker
  METRIC_NAMES = %w(
    processed
    failed
  ).freeze

  sidekiq_options queue: 'critical'
end
